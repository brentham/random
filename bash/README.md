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




Test with Sample Folders
Create test folders (with files inside):

bash
mkdir -p ./images/slides/folder_{1..3}
mkdir -p ./images/markup/folder_{1..3}
touch ./images/slides/folder_{1..3}/testfile.txt
touch ./images/markup/folder_{1..3}/testfile.txt

touch -t $(date -d "2 minutes ago" +%Y%m%d%H%M.%S) ./images/slides/folder_{1..3}/old_file.jpg
touch -t $(date -d "2 minutes ago" +%Y%m%d%H%M.%S) ./images/markup/folder_{1..3}/old_file.jpg

touch ./images/slides/testfile_{1..5}.jpg
touch ./images/markup/testfile_{1..5}.txt

./archive_old_files_test.sh