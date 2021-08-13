#!/usr/bin/env node
const { logger, transports } = require("./logger");
const Commander = require("commander");
const {
  resetTable,
  resetTablesFromSpreadSheet,
} = require("./scripts/reset-tables");
const {
  createIndexesFromSpreadSheet,
  createForeignKeysFromSpreadSheets,
  dropForeignKeysFromSpreadSheets,
} = require("./scripts/create-indexes");
const { setSpreadSheetId, setAuthKeyFile } = require("./gsheet");
const packageJson = require("./package.json");
const config = require("./config");
const fs = require("fs");

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
    "--sheet-id <id>",
    `

  Specify the Spreadsheet ID which serves to update data.
  Also, can be specified by environmental variable GOOGLE_SHEET_ID
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
    "-t, --table <name>",
    `

  Specify a table to be updated, by default update all.
`
  )
  .option(
    "--no-index",
    `

  No create indexes
`
  )
  .option(
    "--no-fk",
    `

  No create foreign keys
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
      "Not auth filename provided either by option or environamental variable. Usign default " +
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

  if (options.sheetId) {
    setSpreadSheetId(options.sheetId);
  } else if (!process.env.GOOGLE_SHEET_ID) {
    logger.error(
      "Spreadsheet ID is required, not provided either by an option or environamental variable."
    );
    return;
  }

  if (options.table) {
    await resetTable(options.table);
    return;
  }

  logger.notice("Drop foreign keys first to avoid deadlocks");
  await dropForeignKeysFromSpreadSheets();

  logger.notice("Reset tables with data from Spreadsheet");
  await resetTablesFromSpreadSheet();

  if (options.fk) {
    logger.notice("Creating foreign keys");
    await createForeignKeysFromSpreadSheets();
  }

  if (options.index) {
    logger.notice("Creating indexes keys");
    await createIndexesFromSpreadSheet();
  }

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
