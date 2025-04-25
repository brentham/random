2. Make the Script Executable
bash
chmod +x /path/to/archive_old_files.sh
3. Set Up a Cron Job
Option A: Using crontab (Linux/TrueNAS CLI)
Run:

bash
crontab -e
Add this line to run the script daily at 2 AM:

bash
0 2 * * * /path/to/archive_old_files.sh
Option B: TrueNAS Scale Web UI (Recommended)
Go to Tasks → Cron Jobs.

Click Add:

Command: /path/to/archive_old_files.sh

Schedule: 0 2 * * * (Runs daily at 2 AM)

Run As User: root (or a user with permissions)

Enabled: ✔️

4. Verify the Script
Manually test the script first:

bash
/path/to/archive_old_files.sh
Check if files moved correctly:

bash
ls -l "$SLIDES_ARCHIVE" "$MARKUP_ARCHIVE"
Check logs:

bash
cat /var/log/archive_script.log









Updated Script (archive_old_files_test.sh)
bash
#!/bin/bash

# Define source and archive directories
SLIDES_SRC="/mnt/datastore/test-data/images/slides"
SLIDES_ARCHIVE="/mnt/datastore/test-data/images/archive"

MARKUP_SRC="/mnt/datastore/test-data/images/markup"
MARKUP_ARCHIVE="/mnt/datastore/test-data/markup/archive"

# Create archive directories if they don't exist
mkdir -p "$SLIDES_ARCHIVE" "$MARKUP_ARCHIVE"

# Move files older than 1 MINUTE (for testing)
find "$SLIDES_SRC" -type f -mmin +1 -exec mv -v {} "$SLIDES_ARCHIVE" \;
find "$MARKUP_SRC" -type f -mmin +1 -exec mv -v {} "$MARKUP_ARCHIVE" \;

# Log the operation
echo "[$(date)] TEST MODE: Files older than 1 minute moved to archive." >> /var/log/archive_script.log
Key Changes:
-mtime +60 → -mmin +1 (moves files older than 1 minute instead of 60 days).

Updated log message to clarify this is a test run.

Set Up a 1-Minute Cron Job
Option A: Command Line (crontab -e)
bash
* * * * * /path/to/archive_old_files_test.sh
* * * * * = Runs every minute.

Option B: TrueNAS Scale Web UI
Go to Tasks → Cron Jobs → Add.

Configure:

Command: /path/to/archive_old_files_test.sh

Schedule: * * * * * (every minute)

Run As User: root (or a user with permissions)

Enabled: ✔️

Testing Steps
Add test files to the source directories:

bash
touch /mnt/datastore/test-data/images/slides/testfile_{1..5}.jpg
touch /mnt/datastore/test-data/images/markup/testfile_{1..5}.txt
Wait 1+ minute, then verify files moved:

bash
ls -l /mnt/datastore/test-data/images/archive/
ls -l /mnt/datastore/test-data/markup/archive/
Check logs:

bash
cat /var/log/archive_script.log
Reverting to 60 Days Later
Once testing is complete:

Update the script back to -mtime +60.

Change the Cron schedule to your desired interval (e.g., 0 2 * * * for daily at 2 AM).

Troubleshooting
Files not moving?

Verify permissions:

bash
ls -ld "$SLIDES_SRC" "$SLIDES_ARCHIVE"
Check if find detects files:

bash
find "$SLIDES_SRC" -type f -mmin +1 -ls
Cron not running?

Check Cron logs:

bash
grep CRON /var/log/syslog