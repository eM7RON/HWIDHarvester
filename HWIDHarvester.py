import functions_framework
import csv
import os

from oauth2client.service_account import ServiceAccountCredentials
import flask
import gspread

@functions_framework.http
def main(request):
    if not request.args or 'token' not in request.args:
        return flask.jsonify({'status': 'error', 'message': 'No credentials provided'})
    elif request.args['token'] != os.environ.get('HWID_HARVESTER_TOKEN'):
        return flask.jsonify({'status': 'error', 'message': 'Invalid credentials'})

    # Set up the credentials
    scope = [
        "https://spreadsheets.google.com/feeds", 
        "https://www.googleapis.com/auth/spreadsheets", 
        "https://www.googleapis.com/auth/drive.file", 
        "https://www.googleapis.com/auth/drive"
    ]

    # Read CSV data from request body
    csv_data = request.data.decode('utf-8')  # Decode the binary data
    # Parse the CSV data into a list
    csv_rows = list(csv.reader(csv_data.split('\n')))[1]

    creds = ServiceAccountCredentials.from_json_keyfile_name(
        '/DIR/HWID_HARVESTER_SECRETS.json',
        scope
    )
    client = gspread.authorize(creds)
    # Access destination Googlesheet
    sheet = client.open_by_key(os.environ.get('HWID_HARVESTER_FILE_ID')).sheet1

    # Use the Google Sheets API to append the data
    try:
        sheet.append_row(csv_rows)
        return flask.jsonify({'status': 'success', 'message': 'Data appended successfully'})
    except Exception as error:
        return flask.jsonify({'status': 'error', 'message': f'{error}'}), 500