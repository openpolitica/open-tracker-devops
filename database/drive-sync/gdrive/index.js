const { google } = require("googleapis");
const config = require("../config");
const { logger } = require("../logger");
const fs = require("fs");

let auth = new google.auth.GoogleAuth({
  keyFile: config.google.keyFile,
  scopes: config.google.scopes,
});

function setAuthKeyFile(fileName) {
  auth = new google.auth.GoogleAuth({
    keyFile: fileName,
    scopes: config.google.scopes,
  });
}

async function getFiles(parent = null) {
  const drive = google.drive("v3");
  const q = parent ? (parent.id ? `'${parent.id}' in parents` : "") : "";
  try {
    const res = await drive.files.list({
      q: q,
      auth: auth,
      pageSize: 10,
      fields: "nextPageToken, files(id, name)",
    });

    const rows = res.data.files;
    if (rows.length === 0) {
      logger.warning("No data found.");
    } else {
      logger.info(`getData: Found ${rows.length} files`);
      rows.map((file) => {
        logger.info(`${file.name} (${file.id})`);
      });
    }
    return rows;
  } catch (err) {
    console.log(err);
    if (err.code === 404) {
      logger.warning(`No folder exist with name ${parent.name}`);
    }
    throw new Error(err);
  }
}

async function getFile(fileName, parent = null) {
  const drive = google.drive("v3");
  let q = "mimeType!='application/vnd.google-apps.folder'";
  q += parent ? (parent.id ? `and ('${parent.id}' in parents)` : "") : "";
  try {
    const res = await drive.files.list({
      q: q,
      auth: auth,
      pageSize: 10,
      fields: "nextPageToken, files(id, name)",
    });

    const rows = res.data.files;
    const fileNames = rows.map((file) => file.name);
    if (fileNames.includes(fileName)) {
      const row = rows[fileNames.indexOf(fileName)];
      logger.info(`File name ${fileName} found with id ${row.id}`);
      return row;
    } else {
      logger.warning(`No file name ${fileName}.`);
      return null;
    }
  } catch (err) {
    if (err.code === 404) {
      logger.warning(`No parent folder exist with name ${parent.name}`);
    }
    throw new Error(err);
  }
}

async function getFolder(folderName, parent = null) {
  const drive = google.drive("v3");
  let q = "mimeType='application/vnd.google-apps.folder'";
  q += parent ? (parent.id ? `and ('${parent.id}' in parents)` : "") : "";
  try {
    const res = await drive.files.list({
      q: q,
      auth: auth,
      pageSize: 10,
      fields: "nextPageToken, files(id, name)",
    });

    const rows = res.data.files;
    const folderNames = rows.map((file) => file.name);
    if (folderNames.includes(folderName)) {
      const row = rows[folderNames.indexOf(folderName)];
      logger.info(`Folder name ${folderName} found with id ${row.id}`);
      return row;
    } else {
      logger.warning(`No folder name ${folderName}.`);
      return null;
    }
  } catch (err) {
    if (err.code === 404) {
      logger.warning(`No parent folder exist with name ${parent.name}`);
    }
    throw new Error(err);
  }
}

async function createFolder(folderName, parent = null) {
  const drive = google.drive("v3");
  let fileMetadata = {
    name: folderName,
    mimeType: "application/vnd.google-apps.folder",
    parents: [parent ? (parent.id ? parent.id : "") : ""],
  };

  try {
    const res = await drive.files.create({
      resource: fileMetadata,
      auth: auth,
      fields: "id, name",
    });

    const file = res.data;
    return file;
  } catch (err) {
    if (err.code === 404) {
      logger.warning(`No parent folder exist with name ${parent.name}`);
    }
    throw new Error(err);
  }
}

async function createFile(fileName, path, parent = null) {
  const drive = google.drive("v3");
  let fileMetadata = {
    name: fileName,
    parents: [parent ? (parent.id ? parent.id : "") : ""],
  };
  let media = {
    mimeType: "text/plain",
    body: fs.createReadStream(path),
  };

  try {
    const res = await drive.files.create({
      resource: fileMetadata,
      media: media,
      auth: auth,
      fields: "id, name",
    });

    const file = res.data;
    return file;
  } catch (err) {
    console.log(err);
    throw new Error(err);
  }
}

async function updateFile(fileInfo, path) {
  const drive = google.drive("v3");
  let media = {
    mimeType: "text/plain",
    body: fs.createReadStream(path),
  };

  try {
    const res = await drive.files.update({
      fileId: fileInfo.id,
      media: media,
      auth: auth,
      fields: "id, name",
    });

    const file = res.data;
    logger.info(`Done updating document: ${fileInfo.name}.`);
    return file;
  } catch (err) {
    console.log(err);
    throw new Error(err);
  }
}

// Based on https://github.com/googleapis/google-api-nodejs-client/issues/1788#issuecomment-522747811
async function downloadFile(fileInfo, destPath) {
  const drive = google.drive("v3");
  const dest = fs.createWriteStream(destPath);
  const res = await drive.files.get(
    { fileId: fileInfo.id, alt: "media", auth: auth },
    { responseType: "stream" }
  );

  return await Promise.all([
    new Promise((resolve, reject) => {
      res.data
        .on("end", () => {
          logger.info(`Done downloading document: ${destPath}.`);
          resolve();
        })
        .on("error", (err) => {
          logger.error("Error downloading document.");
          reject(err);
        })
        .pipe(dest);
    }),
    new Promise((resolve, reject) => {
      dest
        .on("finish", () => {
          logger.info(`Done saving document: ${destPath}.`);
          resolve();
        })
        .on("error", (err) => {
          logger.error("Error saving document.");
          reject(err);
        });
    }),
  ]);
}

//(async () => {
//  backup_folder = await getFolder("data_backup");
//  proj_folder = await getFolder("projects", backup_folder);
//  if (!proj_folder) proj_folder = await createFolder("projects", backup_folder);
//
//  backup_file = await getFile("backup_projects.sql", proj_folder);
//
//  if (!backup_file) {
//    backup_file = await createFile(
//      "backup_projects.sql",
//      "../backup/backup_projects.sql",
//      proj_folder
//    );
//    console.log(backup_file);
//  }
//
//  console.log(backup_file);
//  await updateFile(backup_file, "../backup/backup_projects.sql");
//  await downloadFile(backup_file, "../backup/backup_projects_remote.sql");
//})();

module.exports = {
  getFiles,
  getFolder,
  setAuthKeyFile,
  createFolder,
  createFile,
  getFile,
  updateFile,
  downloadFile,
};
