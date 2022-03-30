const db = require("../db");
const gapi = require("../gsheet");
const config = require("../config");
const md = require("../markdown");
const { logger } = require("../logger");

const DEFAULT_GSHEET_TABLES_INFO = config.sheetNames.tablesInfo;
const DEFAULT_GSHEET_COLUMN_TYPES = config.sheetNames.columnTypes;
const DEFAULT_GSHEET_MARKDOWN_INFO = config.sheetNames.markdownInfo;

async function resetTable(tableName, pk = null, columnTypes = null) {
  //Get info from google-service
  await db.deleteTable(tableName);
  await createAndPopulateTable(tableName, pk, columnTypes);
  return;
}

async function createAndPopulateTable(
  tableName,
  pk = null,
  columnTypes = null,
  markdownInfo = null
) {
  const rows = await gapi.getData(tableName);
  const header = rows[0];
  let tableContent = rows.slice(1);
  if (markdownInfo) {
    const columns = markdownInfo
      .filter((item) => item[0] === tableName)
      ?.map((element) => element[1]);

    if (columns && columns.length > 0) {
      const indexes = columns.map((column) => {
        return header.findIndex((headerColumn) => headerColumn === column);
      });

      tableContent = tableContent.map((row) => md.markdownfyList(row, indexes));
    }
  }

  await db.createTable(tableName, header, pk, columnTypes);
  await db.insertSetOfValues(tableName, header, tableContent);
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
  columnTypes = null,
  markdownInfo = null
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
          columnTypes,
          markdownInfo
        );
      } else {
        logger.warning(
          "resetListOfTables: Table '" +
            tableName +
            "' not in " +
            tablesInfo +
            ". Ignoring."
        );
        return;
      }
    }
    return await createAndPopulateTable(
      tableName,
      tablesInfo,
      columnTypes,
      markdownInfo
    );
  });

  return await Promise.all(promises);
}

async function resetTablesFromSpreadSheet(
  sheetTablesInfo = null,
  sheetColumnTypes = null,
  sheetMarkdownInfo = null,
  enableMarkdown = false
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

  let markdownInfo = null;
  if (enableMarkdown) {
    logger.notice("Markdown conversion enabled.");
    if (!sheetMarkdownInfo) {
      logger.warning(
        "resetTablesFromSpreadSheet: Sheet name with markdown info not provided. Using default '" +
          DEFAULT_GSHEET_MARKDOWN_INFO +
          "'."
      );
      sheetMarkdownInfo = DEFAULT_GSHEET_MARKDOWN_INFO;
    }
    markdownInfo = await gapi.getData(sheetMarkdownInfo, 1);
  }

  const tablesToUpdate = tablesInfo.filter((table) => table[2]);

  const sheetsToUpdate = listOfSheets.filter(
    (sheetName) =>
      tablesToUpdate.findIndex((tableInfo) => tableInfo[0] === sheetName) >= 0
  );

  logger.info("Sheets to update: %O", sheetsToUpdate);
  return await resetListOfTables(
    sheetsToUpdate,
    tablesInfo,
    columnTypes,
    markdownInfo
  );
}

//(async () => {
//  await resetTablesFromSpreadSheet();
//})();

module.exports = {
  resetTable,
  resetListOfTables,
  resetTablesFromSpreadSheet,
};
