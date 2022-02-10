const gdrive = require("../gdrive");
const config = require("../config");
const { logger } = require("../logger");
const path = require("path");
const fs = require("fs");

async function syncFile(
  fileName,
  containingFolderName,
  sourcePath,
  checkDifferent = true,
  backupFolder = null
) {
  if (backupFolder == null) {
    backupFolder = await getFolder(config.google.backupFolder.name);
  }

  containingFolder = await gdrive.getFolder(containingFolderName, backupFolder);

  if (!containingFolder)
    containingFolder = await gdrive.createFolder(
      containingFolderName,
      backupFolder
    );

  backupFile = await gdrive.getFile(fileName, containingFolder);

  if (!backupFile) {
    logger.notice("Backup file doesn't exist, creating the corresponding file");
    backupFile = await gdrive.createFile(
      fileName,
      sourcePath,
      containingFolder
    );
    return;
  }

  if (checkDifferent) {
    logger.notice("Verifying if remote file and local are equal");
    localBackupFolder = path.dirname(fs.realpathSync(sourcePath));
    tempBackupFileName =
      path.basename(fileName, path.extname(fileName)) + "_remote";
    tempBackupFile = path.format({
      dir: localBackupFolder,
      name: tempBackupFileName,
      ext: path.extname(fileName),
    });

    await gdrive.downloadFile(backupFile, tempBackupFile);

    equal = await checkEqualFiles(sourcePath, tempBackupFile);

    if (equal) {
      logger.notice("Files are equal. Not upload files");
      return;
    }
    logger.notice("Files are different. Update files");
  }

  await gdrive.updateFile(backupFile, sourcePath);
  return;
}

async function checkEqualFiles(pathFile1, pathFile2) {
  let tmpBuf = fs.readFileSync(pathFile1);
  let testBuf = fs.readFileSync(pathFile2);

  return tmpBuf.equals(testBuf);
}

//(async () => {
//  await syncFile(
//    "backup_projects.sql",
//    "projects",
//    "../backup/backup_projects.sql",
//    (checkDifferent = false)
//  );
//})();

module.exports = {
  syncFile,
};
