# Blueiris Bulk Export
Need to export a batch of security files but don't want to do it one by one?
This PowerShell script will use the JSON API to export all the cameras and time stamps you want.




## Getting started
1. Download and extract the ZIP
2. Rename "example-credentials.txt" to "credentials.txt" and enter your BlueIris Login Credentials
3. Create your export CSV from the example, or copy our Google Sheet: https://docs.google.com/spreadsheets/d/12va49NumYhnCqeNAU10W9_eVZd0S5bk5COC9zP_MTYw/edit?usp=sharing
4. Ensure export-list.csv is in the script directory before running
5. Run "export.ps1"
6. The script will loop through each line in the CSV and update the Status column to "Completed" when finished. If the script fails, stops or is interupted, you can re-start at any point, and it will kick off where it was stopped.