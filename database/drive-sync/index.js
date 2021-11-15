#!/usr/bin/env node
const { logger, transports } = require("./logger");
const Commander = require("commander");
const { syncFile } = require("./scripts/sync-files");
const {
  downloadFile,
  getFile,
  getFolder,
  setAuthKeyFile,
} = require("./gdrive");
const packageJson = require("./package.json");
const config = require("./config");
const fs = require("fs");
const path = require("path");

const program = new Commander.Command(packageJson.name)
  .version(packageJson.version)
  .usage(`[options]`)
  .option(
    "-l, --log-level <level>",
    `

  Specify the log-level, by default info.
  Possible values: error, warning, notice, info, debug
`
  )
  .option(
    "--backup-folder-id <id>",
    `

  Specify the Spreadsheet ID which serves to update data.
  Also, can be specified by environmental variable GOOGLE_DRIVE_FOLDER_ID
`
  )
  .option(
    "--key-file <filename>",
    `

  Specify the key filename to authenticate with Google service.
  By default, it is key.json
`
  )
  .option(
    "--type <file>",
    `

  Specify the type of backup to synchronize/download.
  Possible values: projects, attendance
`
  )
  .option(
    "--download",
    `

  Download file. You must specify also a dest-path option
`
  )
  .option(
    "--dest-path <destpath>",
    `

  Destination path to the downloaded file.
`
  )
  .option(
    "--update",
    `

  Update file. You must specify also a dest-path option
`
  )
  .option(
    "--force",
    `

  Force update, doesn't verify if there are changes.
`
  )
  .option(
    "--source-path <sourcepath>",
    `

  Source file path to sync/upload the file to Google Drive.
`
  )
  .allowUnknownOption()
  .parse(process.argv);

async function run() {
  const options = program.opts();

  if (options.logLevel) {
    transports.console.level = options.logLevel;
  }
  logger.debug("List of options received: %O", options);

  let keyFile;
  if (options.keyFile) {
    setAuthKeyFile(options.keyFile);
    keyFile = options.keyFile;
  } else if (!process.env.GOOGLE_KEY_FILENAME) {
    logger.notice(
      "Not auth filename provided either by option or environmental variable. Usign default " +
        config.google.keyFile
    );
    keyFile = config.google.keyFile;
  }

  //Check if key file exists
  try {
    if (!fs.existsSync(keyFile)) {
      logger.error(
        "Auth file %s doesn't exist in directory",
        config.google.keyFile
      );
      return;
    }
  } catch (err) {
    console.error(err);
  }

  type = options.type;
  if (!type) {
    logger.error("Type isn't provided, choose one from: %O", config.types);
    return;
  }
  if (!config.types.includes(type)) {
    logger.error(
      "Defined type is not in the list of allowed ones %O",
      config.types
    );
    return;
  }

  backupFolder = config.google.backupFolder;
  if (!backupFolder.id) {
    logger.notice(
      "Backup folder ID not defined, getting from name in config file: %s",
      backupFolder.name
    );
    backupFolder = await getFolder(backupFolder.name);
  }

  if (options.download) {
    if (!options.destPath) {
      logger.error(
        "When download option choosen, requires the dest-path option as well"
      );
      return;
    }
    destPath = options.destPath;
    folderInfo = await getFolder(config.folderNames[type], backupFolder);
    if (!folderInfo) {
      logger.warning("No folder for specified type. Exiting.");
      return;
    }
    fileName = path.format({
      name: config.backupFiles[type],
      ext: config.backupExtension,
    });
    fileInfo = await getFile(fileName, folderInfo);
    if (!fileInfo) {
      logger.warning("No file exists for specified type. Exiting.");
      return;
    }

    let isDirExists =
      fs.existsSync(destPath) && fs.lstatSync(destPath).isDirectory();

    if (isDirExists) {
      logger.notice("Folder path provided, using the name in config");
      destFilePath = path.format({
        dir: destPath,
        name: config.backupFiles[type],
        ext: config.backupExtension,
      });
    } else {
      destFilePath = destPath;
    }
    await downloadFile(fileInfo, destFilePath);
    return;
  }

  if (options.update) {
    if (!options.sourcePath) {
      logger.error(
        "When update option choosen, requires the source-path option as well"
      );
      return;
    }
    sourcePath = options.sourcePath;
    folderName = config.folderNames[type];
    fileName = path.format({
      name: config.backupFiles[type],
      ext: config.backupExtension,
    });

    if (options.force) {
      logger.notice("Forced update");
      await syncFile(
        fileName,
        folderName,
        sourcePath,
        (checkDifferent = false)
      );
    } else {
      await syncFile(fileName, folderName, sourcePath);
    }
    return;
  }

  logger.warning("Neither download or update options configured. Do nothing.");

  return;
}

run().catch(async (reason) => {
  logger.error("Aborting execution.");
  if (reason.command) {
    logger.error(`${reason.command} has failed.`);
  } else {
    logger.error("Unexpected error. Please report it as a bug:");
    logger.error("%O", reason);
  }

  process.exit(1);
});
