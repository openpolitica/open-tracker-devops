const { google } = require("googleapis");
const config = require("../config");
const { logger } = require("../logger");

let auth = new google.auth.GoogleAuth({
  keyFile: config.google.keyFile,
  scopes: config.google.scopes,
});

let spreadsheetId = config.google.spreadsheetId;

function setSpreadSheetId(id) {
  spreadsheetId = id;
}

function setAuthKeyFile(fileName) {
  auth = new google.auth.GoogleAuth({
    keyFile: fileName,
    scopes: config.google.scopes,
  });
}

async function getData(tableName, header = 0) {
  const sheets = google.sheets("v4");
  try {
    const res = await sheets.spreadsheets.values.get({
      auth: auth,
      spreadsheetId: spreadsheetId,
      valueRenderOption: "UNFORMATTED_VALUE",
      dateTimeRenderOption: "FORMATTED_STRING",
      range: `${tableName}!A1:Z`,
    });

    const rows = res.data.values;
    if (rows.length === 0) {
      logger.warning("No data found.");
    } else {
      logger.info(
        `getData: [${tableName}] Found ${rows.length} rows with ${rows[0].length} columns`
      );
      logger.debug("getData: [%s] Header %O", tableName, rows[0]);
    }
    if (header > 0) {
      return rows.slice(header);
    }
    return rows;
  } catch (err) {
    throw new Error(err);
  }
}

async function getTables() {
  const sheets = google.sheets("v4");
  try {
    const res = await sheets.spreadsheets.get({
      auth: auth,
      spreadsheetId: spreadsheetId,
    });

    const listSheets = res.data.sheets.map((sheet) => {
      return sheet.properties.title;
    });
    return listSheets;
  } catch (err) {
    throw new Error(err);
  }
}
//getData("social_network");

module.exports = {
  getData,
  getTables,
  setSpreadSheetId,
  setAuthKeyFile,
};
