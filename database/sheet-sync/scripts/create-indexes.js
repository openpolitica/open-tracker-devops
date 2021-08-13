const db = require("../db");
const gapi = require("../gsheet");
const config = require("../config");
const { logger } = require("../logger/");

const DEFAULT_GSHEET_INDEXES_INFO = config.sheetNames.indexes;
const DEFAULT_GSHEET_FOREIGNKEYS_INFO = config.sheetNames.foreignKeys;

async function createIndexesFromSpreadSheet(sheetIndexInfo = null) {
  if (!sheetIndexInfo) {
    logger.warning(
      "createIndexesFromSpreadSheet: Sheet name with indexes info not provided. Using default '" +
        DEFAULT_GSHEET_INDEXES_INFO +
        "'."
    );
    sheetIndexInfo = DEFAULT_GSHEET_INDEXES_INFO;
  }
  const listOfIndexes = await gapi.getData(sheetIndexInfo, 1);

  await db.createListOfIndexes(listOfIndexes);
  return;
}

async function dropForeignKeysFromSpreadSheets(sheetForeignKeyInfo) {
  if (!sheetForeignKeyInfo) {
    logger.warning(
      "dropForeignKeysFromSpreadSheets: Sheet name with foreign keys info not provided. Using default '" +
        DEFAULT_GSHEET_FOREIGNKEYS_INFO +
        "'."
    );
    sheetForeignKeyInfo = DEFAULT_GSHEET_FOREIGNKEYS_INFO;
  }

  const listOfForeignKeys = await gapi.getData(sheetForeignKeyInfo, 1);

  logger.debug("List of foreign keys: %O", listOfForeignKeys);
  await db.dropListOfForeignKeys(listOfForeignKeys);
  return;
}

async function createForeignKeysFromSpreadSheets(sheetForeignKeyInfo) {
  if (!sheetForeignKeyInfo) {
    logger.warning(
      "createForeignKeysFromSpreadSheets: Sheet name with foreign keys info not provided. Using default '" +
        DEFAULT_GSHEET_FOREIGNKEYS_INFO +
        "'."
    );
    sheetForeignKeyInfo = DEFAULT_GSHEET_FOREIGNKEYS_INFO;
  }

  const listOfForeignKeys = await gapi.getData(sheetForeignKeyInfo, 1);

  logger.debug("List of foreign keys: %O", listOfForeignKeys);
  await db.createListOfForeignKeys(listOfForeignKeys);
  return;
}

//(async () => {
//  await createForeignKeysFromSpreadSheets();
//  await createIndexesFromSpreadSheet();
//})();

module.exports = {
  createIndexesFromSpreadSheet,
  createForeignKeysFromSpreadSheets,
  dropForeignKeysFromSpreadSheets,
};
