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
  types: ["bills", "attendanceVoting"],
  folderNames: {
    bills: "bills",
    attendanceVoting: "attendance-voting",
  },
  backupFiles: {
    bills: "backup_bills",
    attendanceVoting: "backup_attendance_voting",
  },
  backupExtension: ".sql",
};

module.exports = config;
