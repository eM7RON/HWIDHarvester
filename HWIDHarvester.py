import datetime
import functions_framework
import io
import os
import random
import string

from google.oauth2 import service_account
from googleapiclient.discovery import build
from googleapiclient.http import MediaIoBaseUpload
import flask

@functions_framework.http
def main(request):
    
    if not request.args or 'token' not in request.args:
        return flask.jsonify({'status': 'error', 'message': 'No credentials provided'})
    elif request.args['token'] != os.environ.get('HWID_HARVESTER_TOKEN'):
        return flask.jsonify({'status': 'error', 'message': 'Invalid credentials'})
    # Read CSV data from request body
    csv_data = request.data  # Directly read raw data from the request body

    # Authenticate with Google Drive
    scope = ['https://www.googleapis.com/auth/drive']
    service_account_json_key = '/DIR/HWID_HARVESTER_SECRETS.json'
    credentials = service_account.Credentials.from_service_account_file(
        filename=service_account_json_key,
        scopes=scope
    )
    service = build('drive', 'v3', credentials=credentials)

    # Current datetime in the format yyyymmdd-HHmm
    date_time_str = datetime.datetime.now().strftime("%Y%m%d-%H%M")

    # Generate a random alphanumeric string (lowercase) of length 8
    random_str = ''.join(random.choices(string.ascii_lowercase + string.digits, k=8))

    # File metadata for Google Drive
    file_metadata = {
        'name': f'{date_time_str}--{random_str}.csv',
        'parents': [os.environ.get('DESTINATION_FOLDER_ID')]  # Change to your folder ID
    }

    # Create an in-memory file-like object for the CSV data
    fh = io.BytesIO(csv_data)

    # Create a MediaIoBaseUpload object using the in-memory file
    media = MediaIoBaseUpload(fh, mimetype='text/csv', resumable=True)

    # Upload the file
    try:
        file = service.files().create(
            body=file_metadata,
            media_body=media,
            fields='id',
            supportsAllDrives=True # Required for shared drive root
        ).execute()

        return flask.jsonify({'status': 'success', 'message': file.get('id')})
    except Exception as error:
        return flask.jsonify({'status': 'error', 'message': str(error)}), 500
