# Script to reset DB tables from Google Sheets info

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

If you have installed it, the command name is `sheet-sync` and admits the next
options:

```
sheet-sync [options]
```

**Options:**

- `-V, --version` output the version number
- `-l, --log-level <level>`

  Specify the log-level, by default info.
  Possible values: error, warning, notice, info, debug

- `--sheet-id <id>`

  Specify the Spreadsheet ID which serves to update data.
  Also, can be specified by environmental variable `GOOGLE_SHEET_ID`

- `--key-file <filename>`

  Specify the key filename to authenticate with Google service.
  By default, it is `key.json`.

- `-t, --table <name>`

  Specify a table to be updated, by default update all (in development).

- `--no-index`

  No create indexes

- `--no-fk`

  No create foreign keys

- `--enable-markdown`

  Enable conversion from Markdown text to HTML

- `-h, --help` display help for command

From these options, providing the `--sheet-id` is mandatory either via the
command line or via an environmental variable `GOOGLE_SHEET_ID`.

Then, it is required also that you provide the key file downloaded from the Google
service account, explained above.

On the other hand, to connect with database, which is a Postgres DB, you should
provide some environment variables, otherwise, default values are considered:

| Variable     | Default          |
| ------------ | ---------------- |
| `PGHOST`     | localhost        |
| `PGUSER`     | process.env.USER |
| `PGDATABASE` | process.env.USER |
| `PGPASSWORD` | null             |
| `PORT`       | 5432             |

In case you are using the script from the source folder, you can call it via:

```
npm run reset -- [options]
```

Where `[options]` are the options described above.
