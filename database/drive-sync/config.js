require("dotenv").config();

const config = {
  google: {
    backupFolder: {
      id: process.env.GOOGLE_DRIVE_FOLDER_ID,
      name: "data_backup",
    },
    keyFile: process.env.GOOGLE_KEY_FILENAME || "./key.json",
    scopes: [
      "https://www.googleapis.com/auth/drive",
      "https://www.googleapis.com/auth/drive.appdata",
      "https://www.googleapis.com/auth/drive.file",
      "https://www.googleapis.com/auth/drive.metadata",
      "https://www.googleapis.com/auth/drive.metadata.readonly",
      "https://www.googleapis.com/auth/drive.photos.readonly",
      "https://www.googleapis.com/auth/drive.readonly",
    ],
  },
  types: ["projects", "attendance"],
  folderNames: {
    projects: "projects",
    attendance: "attendance",
  },
  backupFiles: {
    projects: "backup_projects",
    attendance: "backup_attendance",
  },
  backupExtension: ".sql",
};

module.exports = config;
