import boto3
import argparse
import time
import os
import sys
import shutil
from datetime import datetime, timedelta
from pathlib import Path

def get_restore_status(head_response):
    """Check restore status from head_object response."""
    restore_status = head_response.get('Restore', '')
    if 'ongoing-request="true"' in restore_status:
        return 'in_progress'
    elif 'ongoing-request="false"' in restore_status:
        return 'restored'
    return 'not_started'

def init_restore(s3, bucket, key, storage_class, days):
    """Initiate restore request with appropriate tier."""
    tier = 'Bulk' if storage_class == 'DEEP_ARCHIVE' else 'Standard'
    restore_request = {
        'Days': days,
        'GlacierJobParameters': {'Tier': tier}
    }
    s3.restore_object(Bucket=bucket, Key=key, RestoreRequest=restore_request)
    return tier

def download_file(s3, bucket, key, download_dir):
    """Download file to local directory with path preservation."""
    local_path = os.path.join(download_dir, key)
    os.makedirs(os.path.dirname(local_path), exist_ok=True)
    s3.download_file(bucket, key, local_path)
    return local_path

def copy_to_network_share(local_path, network_share):
    """Copy file to network share while preserving directory structure."""
    try:
        # Convert to Path objects for easier manipulation
        src = Path(local_path)
        dest_dir = Path(network_share) / src.parent.relative_to(args.download_dir)
        
        # Create destination directory if needed
        dest_dir.mkdir(parents=True, exist_ok=True)
        
        # Copy file
        dest_path = dest_dir / src.name
        shutil.copy2(src, dest_path)
        return str(dest_path)
    except Exception as e:
        print(f"  Network copy error: {str(e)}")
        return None

def main():
    parser = argparse.ArgumentParser(description='Restore files from S3 Glacier and copy to network share')
    parser.add_argument('--bucket', required=True, help='S3 bucket name')
    parser.add_argument('--keys', nargs='*', default=[], help='List of object keys to restore')
    parser.add_argument('--key-file', help='File containing object keys (one per line)')
    parser.add_argument('--prefix', help='Restore objects with this prefix')
    parser.add_argument('--download-dir', help='Local download directory')
    parser.add_argument('--network-share', help='Network share path (e.g., /mnt/nas/restored)')
    parser.add_argument('--restore-days', type=int, default=7, help='Days to keep restored files (default: 7)')
    parser.add_argument('--wait', action='store_true', help='Wait until restoration completes')
    parser.add_argument('--check-interval', type=int, default=60, help='Status check interval in minutes (default: 60)')
    parser.add_argument('--timeout', type=int, default=24, help='Max wait time in hours (default: 24)')
    
    args = parser.parse_args()
    s3 = boto3.client('s3')
    keys = set(args.keys)

    # Validate arguments
    if args.network_share and not args.download_dir:
        parser.error("--download-dir is required when using --network-share")

    # Collect keys from input sources
    if args.key_file:
        with open(args.key_file) as f:
            keys.update(line.strip() for line in f if line.strip())
    
    if args.prefix:
        paginator = s3.get_paginator('list_objects_v2')
        for page in paginator.paginate(Bucket=args.bucket, Prefix=args.prefix):
            for obj in page.get('Contents', []):
                keys.add(obj['Key'])

    if not keys:
        print("No keys specified for restoration")
        return

    status_map = {}
    print(f"\n{'Key':<50} {'Storage Class':<20} {'Status':<15}")
    print("-" * 90)

    # Initial status check
    for key in keys:
        try:
            head = s3.head_object(Bucket=args.bucket, Key=key)
            sc = head.get('StorageClass', '')
            
            if sc in ['GLACIER', 'DEEP_ARCHIVE']:
                status = get_restore_status(head)
                tier = init_restore(s3, args.bucket, key, sc, args.restore_days) if status == 'not_started' else 'N/A'
                if status == 'not_started':
                    print(f"{key[:48]:<50} {sc:<20} {'Restore started':<15} (Tier: {tier})")
                    status = 'in_progress'
                else:
                    print(f"{key[:48]:<50} {sc:<20} {status.replace('_', ' '):<15}")
            else:
                status = 'not_glacier'
                print(f"{key[:48]:<50} {sc:<20} {'Skipped (non-glacier)':<15}")
                
            status_map[key] = status
        except Exception as e:
            print(f"{key[:48]:<50} {'ERROR':<20} {str(e)[:30]:<15}")
            status_map[key] = 'error'

    # Wait for restoration if requested
    pending = [k for k, s in status_map.items() if s == 'in_progress']
    if args.wait and pending:
        print(f"\nWaiting for restoration ({len(pending)} objects)...")
        timeout = datetime.now() + timedelta(hours=args.timeout)
        check_secs = args.check_interval * 60
        
        while pending and datetime.now() < timeout:
            time.sleep(check_secs)
            print(f"\nCheck at {datetime.now().strftime('%H:%M:%S')}")
            
            for key in pending[:]:
                try:
                    head = s3.head_object(Bucket=args.bucket, Key=key)
                    status_map[key] = get_restore_status(head)
                    
                    if status_map[key] == 'restored':
                        print(f"  {key[:60]} - RESTORED")
                        pending.remove(key)
                    else:
                        print(f"  {key[:60]} - In progress...")
                except Exception:
                    continue
        
        if pending:
            print(f"\nWarning: Timeout reached with {len(pending)} objects unrestored")

    # Download restored files
    if args.download_dir:
        restored = [k for k, s in status_map.items() if s == 'restored']
        print(f"\nDownloading {len(restored)} restored files...")
        
        for key in restored:
            try:
                local_path = download_file(s3, args.bucket, key, args.download_dir)
                print(f"  Downloaded: {key} \n\t-> {local_path}")
                
                # Copy to network share if requested
                if args.network_share:
                    dest_path = copy_to_network_share(local_path, args.network_share)
                    if dest_path:
                        print(f"  Copied to network share: {dest_path}")
            except Exception as e:
                print(f"  Download failed for {key}: {str(e)}")

if __name__ == '__main__':
    main()