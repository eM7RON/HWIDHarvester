HWIDHarvester is a tool designed to harvest hardware IDs from Windows devices for enablement of Windows Autopilot. It has 2 main components:

1. The HWIDHarvester.ps1 script should be packaged as a Win32 app and deployed to Windows devices. The script generates the HWID.csv file and then uses a post request to upload it to a Google Cloud function.

You will need to create a script named env.ps1 containting an access token ($TOKEN). The token should follow the same rules for a strong password.

2. The HWIDHarvester.py script is to be run in a Python 12 Google Cloud function environment. It receives HWID.csv files from devices and then using the Google Drive API uploads them into a desired folder.

The value of $TOKEN should be set as a secret accessible via an environment variable 'HWID_HARVESTER_TOKEN'.

The file id of the destination Google sheet should be accesible via an environment variable 'HWID_HARVESTER_FILE_ID'.

The Googlesheets and Google Drive APIs should be enabled. A service account should be created and an credential file created accesible via a mounted drive at location: '/DIR/HWID_HARVESTER_SECRETS.json'.