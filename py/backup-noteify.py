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
        f"Prefix: {prefix}",
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

# Existing Glacier functions (get_restore_status, init_restore, download_file, copy_to_network_share)
# ... [Keep all existing glacier functions unchanged from previous implementation] ...

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
    parser.add_argument('--profile', help='AWS profile name to use', default=None)
    
    args = parser.parse_args()
    
    # Initialize AWS session
    if args.profile:
        session = boto3.Session(profile_name=args.profile)
    else:
        session = boto3.Session()
    
    s3 = session.client('s3')
    keys = set(args.keys)
    
    # ... [Rest of the glacier restoration logic remains unchanged] ...
    
    # After all processing is complete
    report = generate_report(
        status_map, 
        args.download_dir, 
        args.network_share,
        args.bucket,
        args.prefix or "N/A"
    )
    logger.info("\n" + report)
    
    # Determine notification status
    success = not any(status == 'error' for status in status_map.values()) and not pending
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

if __name__ == '__main__':
    main()