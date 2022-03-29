# Script to synchronize DB backups to Google Drive

## Requirements

**NOTE** This information is taken from the google-api documentation for nodejs
from: https://github.com/googleapis/google-api-nodejs-client#service-account-credentials

### Create a service account

Service accounts allow you to perform server to server, app-level authentication using a robot account. You will create a service account, download a keyfile, and use that to authenticate to Google APIs. To create a service account:

- Go to the [Create Service Account Key page](https://console.cloud.google.com/apis/credentials/serviceaccountkey)
- Click the button `Create new service account`
- Enter the service account name and the corresponding id.
- Add the additional information regarding users and project permissions
  (optional)
- Create the service account.

Once it is created you should create a keyfile, then follow the next steps:

- Enter to the newly created service account
- Go to the `Keys` tab
- Click the button `Add key` and select `JSON`.

Save the service account credential file somewhere safe, and do not check this file into source control!

### Add permissions to the document

If you want to perform operations in a private file, you should add the service
mail (e.g. service-name@project-name.iam.gserviceaccount.com) to the list of
shared users in your document.

You can read this reference which explains this specific requirement:
https://github.com/juampynr/google-spreadsheet-reader

## How to use

The script could be used installed in your local environment, or directly from the
location of the package source.

If you have installed it, the command name is `drive-sync` and admits the next
options:

```
drive-sync [options]
```

**Options:**

- `-V, --version` output the version number
- `-l, --log-level <level>`

  Specify the log-level, by default info.
  Possible values: error, warning, notice, info, debug

- `--backup-folder-id <id>`

  Specify the Spreadsheet ID which serves to update data.
  Also, can be specified by environmental variable GOOGLE_DRIVE_FOLDER_ID

- `--key-file <filename>`

  Specify the key filename to authenticate with Google service.
  By default, it is key.json

- `--type <file>`

  Specify the type of backup to synchronize/download.
  Possible values: projects, attendance

- `--download`

  Download file. You must specify also a dest-path option

- `--dest-path <destpath>`

  Destination path to the downloaded file.

- `--update`

  Update file. You must specify also a dest-path option

- `--force`

  Force update, doesn't verify if there are changes.

- `--source-path <sourcepath>`

  Source file path to sync/upload the file to Google Drive.

- `-h, --help` display help for command

It is required that you provide the key file downloaded from the Google
service account, explained above.

In addition to these you should provide the folder ID for the backups via the
option`--backup-folder-id`, otherwise, it will be obtained from the folder name
in the config file at `google.backupFolder.name` key.

There are two types supported, that you must specify via the `--type` option:

- **bills** used to sync the projects backup
- **attendanceVoting** used to sync the attendance backup

Finally, there are two modes allowed:

- **Update** specified via the option `--update`, used to synchronize the
  backup at Google Drive checking if they are different. Use it issuing the
  following command:

```
npm run update -- [options]
```

- **Download** specified via the option `--download`, used to download the
  backup at Google Drive. Use it issuing the following command:

```
npm run download -- [options]
```

In both cases, `[options]` are the options described above.
