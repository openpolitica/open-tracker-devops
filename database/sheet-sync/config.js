require("dotenv").config();

const config = {
  db: {
    host: process.env.PGHOST || "localhost",
    user: process.env.PGUSER || process.env.USER,
    database: process.env.PGDATABASE || process.env.USER,
    password: process.env.PGPASSWORD || null,
    port: process.env.PORT || 5432,
  },
  google: {
    spreadsheetId: process.env.GOOGLE_SHEET_ID,
    keyFile: process.env.GOOGLE_KEY_FILENAME || "./key.json",
    scopes: ["https://www.googleapis.com/auth/spreadsheets.readonly"],
  },
  sheetNames: {
    tablesInfo: "tables",
    columnTypes: "column_type",
    indexes: "indexes",
    foreignKeys: "foreign_keys",
  },
};

module.exports = config;
