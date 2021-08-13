const db = require("../db");
const gapi = require("../gsheet");
const config = require("../config");
const { logger } = require("../logger");

const DEFAULT_GSHEET_TABLES_INFO = config.sheetNames.tablesInfo;
const DEFAULT_GSHEET_COLUMN_TYPES = config.sheetNames.columnTypes;

async function resetTable(tableName, pk = null, columnTypes = null) {
  //Get info from google-service
  await db.deleteTable(tableName);
  await createAndPopulateTable(tableName, pk, columnTypes);
  return;
}

async function createAndPopulateTable(
  tableName,
  pk = null,
  columnTypes = null
) {
  const rows = await gapi.getData(tableName);
  await db.createTable(tableName, rows[0], pk, columnTypes);
  await db.insertSetOfValues(tableName, rows[0], rows.slice(1));
  return;
}

async function deleteListOfTables(listOfTables) {
  let promises = listOfTables.map(async function (tableName) {
    return await db.deleteTable(tableName);
  });

  return await Promise.all(promises);
}

async function resetListOfTables(
  listOfTables,
  tablesInfo = null,
  columnTypes = null
) {
  if (!tablesInfo) {
    logger.warning(
      "resetListOfTables: Table info not defined. Not primary keys provided."
    );
  }
  logger.notice("Deleting list of tables");
  await deleteListOfTables(listOfTables);

  logger.notice("Creating and populating data");
  let promises = listOfTables.map(async function (tableName) {
    if (tablesInfo) {
      let index = tablesInfo.findIndex(
        (tableInfo) => tableInfo[0] === tableName
      );
      if (index >= 0) {
        return await createAndPopulateTable(
          tableName,
          tablesInfo[index][1],
          columnTypes
        );
      } else {
        logger.warning(
          "resetListOfTables: Table '" +
            tableName +
            "' not in " +
            tablesInfo +
            ". Ignoring."
        );
      }
    }
    return await createAndPopulateTable(tableName, tablesInfo, columnTypes);
  });

  return await Promise.all(promises);
}

async function resetTablesFromSpreadSheet(
  sheetTablesInfo = null,
  sheetColumnTypes = null
) {
  const listOfSheets = await gapi.getTables();

  if (!sheetTablesInfo) {
    logger.warning(
      "resetTablesFromSpreadSheet: Sheet name with tables info not provided. Using default '" +
        DEFAULT_GSHEET_TABLES_INFO +
        "'."
    );
    sheetTablesInfo = DEFAULT_GSHEET_TABLES_INFO;
  }

  const tablesInfo = await gapi.getData(sheetTablesInfo, 1);

  if (!sheetColumnTypes) {
    logger.warning(
      "resetTablesFromSpreadSheet: Sheet name with columns type not provided. Using default '" +
        DEFAULT_GSHEET_COLUMN_TYPES +
        "'."
    );
    sheetColumnTypes = DEFAULT_GSHEET_COLUMN_TYPES;
  }

  const columnTypes = await gapi.getData(sheetColumnTypes, 1);

  const tablesToUpdate = tablesInfo.filter((table) => table[2]);

  const sheetsToUpdate = listOfSheets.filter(
    (sheetName) =>
      tablesToUpdate.findIndex((tableInfo) => tableInfo[0] === sheetName) >= 0
  );

  logger.info("Sheets to update: %O", sheetsToUpdate);
  return await resetListOfTables(sheetsToUpdate, tablesInfo, columnTypes);
}

//(async () => {
//  await resetTablesFromSpreadSheet();
//})();

module.exports = {
  resetTable,
  resetListOfTables,
  resetTablesFromSpreadSheet,
};
