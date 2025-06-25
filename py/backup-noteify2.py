import boto3
import argparse
import time
import os
import sys
import shutil
import smtplib
import logging
import json
import requests
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from datetime import datetime, timedelta
from pathlib import Path

# Load environment variables from .env file if available
try:
    from dotenv import load_dotenv
    load_dotenv()
except ImportError:
    # python-dotenv not installed, continue without it
    pass

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(),
        logging.FileHandler('glacier_restore.log')
    ]
)
logger = logging.getLogger(__name__)

# Notification functions using environment variables
def send_email_notification(subject, body):
    """Send email notification using environment variables"""
    if not all(os.getenv(var) for var in ['EMAIL_FROM', 'EMAIL_TO', 'SMTP_SERVER', 'SMTP_USER', 'SMTP_PASSWORD']):
        logger.warning("Skipping email notification - missing environment variables")
        return False
    
    try:
        # Create message
        msg = MIMEMultipart()
        msg['Subject'] = subject
        msg['From'] = os.getenv('EMAIL_FROM')
        msg['To'] = os.getenv('EMAIL_TO')
        msg.attach(MIMEText(body, 'plain'))
        
        # Connect to SMTP server
        smtp_server = os.getenv('SMTP_SERVER')
        smtp_port = int(os.getenv('SMTP_PORT', '587'))
        
        with smtplib.SMTP(smtp_server, smtp_port) as server:
            server.starttls()
            server.login(os.getenv('SMTP_USER'), os.getenv('SMTP_PASSWORD'))
            server.send_message(msg)
        
        logger.info("Email notification sent successfully")
        return True
    except Exception as e:
        logger.error(f"Email send failed: {str(e)}")
        return False

def send_teams_notification(title, message, theme_color="0078D7"):
    """Send Microsoft Teams notification using environment variable"""
    webhook_url = os.getenv('TEAMS_WEBHOOK_URL')
    if not webhook_url:
        logger.warning("Skipping Teams notification - TEAMS_WEBHOOK_URL not set")
        return False
    
    try:
        payload = {
            "@type": "MessageCard",
            "@context": "http://schema.org/extensions",
            "themeColor": theme_color,
            "summary": title,
            "sections": [{
                "activityTitle": title,
                "activitySubtitle": datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
                "text": message,
            }]
        }
        
        response = requests.post(
            webhook_url,
            json=payload,
            headers={'Content-Type': 'application/json'},
            timeout=10
        )
        
        if response.status_code == 200:
            logger.info("Teams notification sent successfully")
            return True
        else:
            logger.error(f"Teams notification failed: {response.status_code} {response.text}")
            return False
    except Exception as e:
        logger.error(f"Teams send error: {str(e)}")
        return False

# TEST FUNCTIONS =============================================================

def test_email_notification():
    """Test email notification functionality"""
    logger.info("Testing email notification...")
    
    # Check if required environment variables are set
    required_vars = ['EMAIL_FROM', 'EMAIL_TO', 'SMTP_SERVER', 'SMTP_USER', 'SMTP_PASSWORD']
    missing_vars = [var for var in required_vars if not os.getenv(var)]
    
    if missing_vars:
        logger.error(f"Missing required environment variables: {', '.join(missing_vars)}")
        return False
    
    # Send test email
    subject = "TEST: Glacier Restore Notification"
    body = (
        "This is a test notification from the Glacier Restore Script.\n\n"
        "If you're receiving this email, it means:\n"
        "1. The notification system is working correctly\n"
        "2. Your SMTP configuration is valid\n\n"
        f"Server: {os.getenv('SMTP_SERVER')}:{os.getenv('SMTP_PORT', '587')}\n"
        f"Sent at: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}"
    )
    
    try:
        success = send_email_notification(subject, body)
        if success:
            logger.info("Email test succeeded! Please check your inbox.")
        return success
    except Exception as e:
        logger.error(f"Email test failed: {str(e)}")
        return False

def test_teams_notification():
    """Test Microsoft Teams notification functionality"""
    logger.info("Testing Teams notification...")
    
    if not os.getenv('TEAMS_WEBHOOK_URL'):
        logger.error("TEAMS_WEBHOOK_URL environment variable not set")
        return False
    
    # Send test message
    title = "TEST: Glacier Restore Notification"
    message = (
        "This is a test notification from the Glacier Restore Script.\n\n"
        "✅ If you're seeing this message, it means:\n"
        "- The notification system is working correctly\n"
        "- Your Teams webhook URL is valid\n\n"
        f"Sent at: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}"
    )
    
    try:
        success = send_teams_notification(title, message, theme_color="00FF00")
        if success:
            logger.info("Teams test succeeded! Please check your Teams channel.")
        return success
    except Exception as e:
        logger.error(f"Teams test failed: {str(e)}")
        return False

# ============================================================================

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

def copy_to_network_share(local_path, network_share, download_dir):
    """Copy file to network share while preserving directory structure."""
    try:
        # Convert to Path objects for easier manipulation
        src = Path(local_path)
        relative_path = src.relative_to(download_dir)
        dest_path = Path(network_share) / relative_path
        
        # Create destination directory if needed
        dest_path.parent.mkdir(parents=True, exist_ok=True)
        
        # Copy file
        shutil.copy2(src, dest_path)
        return str(dest_path)
    except Exception as e:
        logger.error(f"Network copy error: {str(e)}")
        return None

def generate_report(status_map, download_dir, network_share, bucket, prefix):
    """Generate detailed summary report of the operation"""
    restored = [k for k, s in status_map.items() if s == 'restored']
    pending = [k for k, s in status_map.items() if s == 'in_progress']
    errors = [k for k, s in status_map.items() if s == 'error']
    skipped = [k for k, s in status_map.items() if s == 'not_glacier']
    
    # Calculate sizes for restored files (if available)
    restored_size = 0
    for key in restored:
        try:
            head = s3.head_object(Bucket=bucket, Key=key)
            restored_size += head.get('ContentLength', 0)
        except:
            pass
    
    report = [
        "GLACIER RESTORE REPORT",
        "======================",
        f"Completed at: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}",
        f"Bucket: {bucket}",
        f"Prefix: {prefix or 'All keys'}",
        f"Restored: {len(restored)} files ({restored_size/1024/1024:.2f} MB)",
        f"Pending: {len(pending)} files",
        f"Errors: {len(errors)} files",
        f"Skipped (non-glacier): {len(skipped)} files",
        ""
    ]
    
    if download_dir:
        report.append(f"Local download directory: {download_dir}")
    if network_share:
        report.append(f"Network share destination: {network_share}")
    
    # Add top 5 issues if any
    if pending:
        report.extend(["", "PENDING FILES:", "--------------"])
        report.extend(pending[:5])
        if len(pending) > 5:
            report.append(f"... and {len(pending)-5} more")
    
    if errors:
        report.extend(["", "ERROR FILES:", "------------"])
        report.extend(errors[:5])
        if len(errors) > 5:
            report.append(f"... and {len(errors)-5} more")
    
    return "\n".join(report)

def main():
    # Initialize variables
    status_map = {}
    pending = []
    
    # Parse arguments
    parser = argparse.ArgumentParser(description='Restore files from S3 Glacier and copy to network share')
    parser.add_argument('--bucket', help='S3 bucket name')
    parser.add_argument('--keys', nargs='*', default=[], help='List of object keys to restore')
    parser.add_argument('--key-file', help='File containing object keys (one per line)')
    parser.add_argument('--prefix', help='Restore objects with this prefix')
    parser.add_argument('--download-dir', help='Local download directory')
    parser.add_argument('--network-share', help='Network share path (e.g., /mnt/nas/restored)')
    parser.add_argument('--restore-days', type=int, default=7, help='Days to keep restored files (default: 7)')
    parser.add_argument('--wait', action='store_true', help='Wait until restoration completes')
    parser.add_argument('--check-interval', type=int, default=60, help='Status check interval in minutes (default: 60)')
    parser.add_argument('--timeout', type=int, default=24, help='Max wait time in hours (default: 24)')
    parser.add_argument('--profile', help='AWS profile name to use', default=None)
    
    # Add test arguments
    parser.add_argument('--test-email', action='store_true', help='Test email notification system')
    parser.add_argument('--test-teams', action='store_true', help='Test Teams notification system')
    
    # Add .env argument
    parser.add_argument('--env-file', help='Path to .env file for configuration', default='.env')
    
    args = parser.parse_args()
    
    # Load .env file if specified
    if args.env_file:
        try:
            from dotenv import load_dotenv
            if os.path.exists(args.env_file):
                load_dotenv(args.env_file)
                logger.info(f"Loaded environment variables from {args.env_file}")
            else:
                logger.warning(f"Env file not found: {args.env_file}")
        except ImportError:
            logger.warning("python-dotenv not installed, skipping .env loading")
    
    # Run tests if requested
    if args.test_email:
        result = test_email_notification()
        sys.exit(0 if result else 1)
    
    if args.test_teams:
        result = test_teams_notification()
        sys.exit(0 if result else 1)
    
    # Validate required arguments for actual restore
    if not args.bucket:
        logger.error("Bucket name is required for restoration. Use --bucket")
        sys.exit(1)
    
    # Initialize AWS session
    if args.profile:
        session = boto3.Session(profile_name=args.profile)
    else:
        session = boto3.Session()
    
    global s3
    s3 = session.client('s3')
    keys = set(args.keys)
    
    # Validate arguments
    if args.network_share and not args.download_dir:
        logger.error("--download-dir is required when using --network-share")
        sys.exit(1)

    # Collect keys from input sources
    if args.key_file:
        try:
            with open(args.key_file) as f:
                keys.update(line.strip() for line in f if line.strip())
        except Exception as e:
            logger.error(f"Error reading key file: {str(e)}")
    
    if args.prefix:
        try:
            paginator = s3.get_paginator('list_objects_v2')
            for page in paginator.paginate(Bucket=args.bucket, Prefix=args.prefix):
                for obj in page.get('Contents', []):
                    keys.add(obj['Key'])
        except Exception as e:
            logger.error(f"Error listing objects: {str(e)}")

    if not keys:
        logger.error("No keys specified for restoration")
        sys.exit(1)

    # Log start of operation
    logger.info(f"Starting restoration for {len(keys)} objects")
    
    # Initial status check
    logger.info(f"\n{'Key':<50} {'Storage Class':<20} {'Status':<15}")
    logger.info("-" * 90)

    for key in keys:
        try:
            head = s3.head_object(Bucket=args.bucket, Key=key)
            sc = head.get('StorageClass', '')
            
            if sc in ['GLACIER', 'DEEP_ARCHIVE']:
                status = get_restore_status(head)
                if status == 'not_started':
                    tier = init_restore(s3, args.bucket, key, sc, args.restore_days)
                    logger.info(f"{key[:48]:<50} {sc:<20} {'Restore started':<15} (Tier: {tier})")
                    status = 'in_progress'
                else:
                    logger.info(f"{key[:48]:<50} {sc:<20} {status.replace('_', ' '):<15}")
            else:
                status = 'not_glacier'
                logger.info(f"{key[:48]:<50} {sc:<20} {'Skipped (non-glacier)':<15}")
                
            status_map[key] = status
        except Exception as e:
            logger.error(f"{key[:48]:<50} {'ERROR':<20} {str(e)[:30]:<15}")
            status_map[key] = 'error'

    # Wait for restoration if requested
    pending = [k for k, s in status_map.items() if s == 'in_progress']
    if args.wait and pending:
        logger.info(f"\nWaiting for restoration of {len(pending)} objects...")
        timeout = datetime.now() + timedelta(hours=args.timeout)
        check_secs = args.check_interval * 60
        
        while pending and datetime.now() < timeout:
            time.sleep(check_secs)
            logger.info(f"\nCheck at {datetime.now().strftime('%H:%M:%S')}")
            
            for key in pending[:]:
                try:
                    head = s3.head_object(Bucket=args.bucket, Key=key)
                    status_map[key] = get_restore_status(head)
                    
                    if status_map[key] == 'restored':
                        logger.info(f"  {key[:60]} - RESTORED")
                        pending.remove(key)
                    else:
                        logger.info(f"  {key[:60]} - In progress...")
                except Exception as e:
                    logger.error(f"  {key[:60]} - Error: {str(e)}")
                    continue
        
        if pending:
            logger.warning(f"Timeout reached with {len(pending)} objects unrestored")
    
    # After all processing is complete
    # Recompute pending for final status
    pending = [k for k, s in status_map.items() if s == 'in_progress']
    has_errors = any(status == 'error' for status in status_map.values())
    success = not has_errors and not pending
    
    # Generate report
    report = generate_report(
        status_map, 
        args.download_dir, 
        args.network_share,
        args.bucket,
        args.prefix
    )
    logger.info("\n" + report)
    
    # Download restored files
    if args.download_dir:
        restored = [k for k, s in status_map.items() if s == 'restored']
        logger.info(f"\nDownloading {len(restored)} restored files...")
        
        for key in restored:
            try:
                local_path = download_file(s3, args.bucket, key, args.download_dir)
                logger.info(f"  Downloaded: {key} \n\t-> {local_path}")
                
                # Copy to network share if requested
                if args.network_share:
                    dest_path = copy_to_network_share(local_path, args.network_share, args.download_dir)
                    if dest_path:
                        logger.info(f"  Copied to network share: {dest_path}")
            except Exception as e:
                logger.error(f"  Download failed for {key}: {str(e)}")

    # Prepare notification
    notification_title = f"Glacier Restore {'✅ Succeeded' if success else '⚠️ Completed with Issues'}"
    theme_color = "00FF00" if success else "FF0000"
    
    # Send notifications based on environment variables
    email_sent = False
    teams_sent = False
    
    if os.getenv('ENABLE_EMAIL_NOTIFICATIONS', 'false').lower() == 'true':
        email_body = report + "\n\nOperation " + ("succeeded" if success else "completed with issues")
        email_sent = send_email_notification(
            subject=notification_title,
            body=email_body
        )
    
    if os.getenv('ENABLE_TEAMS_NOTIFICATIONS', 'false').lower() == 'true':
        teams_message = report.replace("\n", "\n\n")
        teams_sent = send_teams_notification(
            title=notification_title,
            message=teams_message,
            theme_color=theme_color
        )
    
    # Log notification results
    logger.info(f"Notifications: Email {'sent' if email_sent else 'not sent'}, "
                f"Teams {'sent' if teams_sent else 'not sent'}")
    
    # Exit with appropriate status
    if success:
        logger.info("Restore completed successfully")
        sys.exit(0)
    else:
        logger.error("Restore completed with errors")
        sys.exit(1)

if __name__ == '__main__':
    main()