const { Pool } = require("pg");
const config = require("../config");
const { logger } = require("../logger");

const pool = new Pool({
  user: config.db.user,
  host: config.db.host,
  database: config.db.database,
  password: config.db.password,
  port: config.db.port,
});

pool.on("error", (err, client) => {
  logger.error("Unexpected error on idle client %O", err);
  process.exit(-1);
});

const db = {
  query: async function (text, values) {
    try {
      const res = await pool.query(text, values);
      return res.rows;
    } catch (err) {
      throw new Error(err.stack);
    }
  },
};

async function createTable(
  tableName,
  columnNames,
  pk = null,
  columnTypes = null
) {
  if (!pk) {
    logger.warning(
      "createTable: [" +
        tableName +
        "] Primary key not defined. Not included in creation"
    );
  } else {
    if (columnNames.findIndex((columnName) => columnName == pk) < 0) {
      logger.warning(
        "createTable: [" +
          tableName +
          "] Indicated primary key not defined in columns names. Not considered."
      );
    }
  }
  if (!columnTypes) {
    logger.warning(
      "createTable: [" +
        tableName +
        "] ColumnTypes no provided. All columns set as TEXT."
    );
  }

  let query = "CREATE TABLE IF NOT EXISTS ";
  query += tableName;
  query += " (";
  query += columnNames
    .map((columnName) => {
      if (columnTypes) {
        let index = columnTypes.findIndex((row) => row[0] === columnName);
        if (index >= 0) {
          return (
            columnName +
            " " +
            columnTypes[index][1] +
            " " +
            (columnTypes[index][2] ? "NULL" : "NOT NULL") +
            (columnName === pk ? " PRIMARY KEY" : "")
          );
        }
      }
      return columnName + " TEXT" + (columnName === pk ? " PRIMARY KEY" : "");
    })
    .join(",");
  query += ")";

  logger.debug(query);
  return await db.query(query);
}

async function deleteTable(tableName) {
  let query = "DROP TABLE IF EXISTS ";
  query += tableName;
  query += " CASCADE";

  logger.debug(query);
  return await db.query(query);
}

async function insertValues(tableName, columnNames, values) {
  //Check lenght of columns and values, trim to the minor value
  if (columnNames.length < values.length) {
    values = values.slice(0, columnNames.length);
  }

  if (columnNames.length > values.length) {
    columnNames = columnNames.slice(0, values.length);
  }

  let query = "INSERT INTO ";
  query += tableName;
  query += " (";
  query += columnNames.join(",");
  query += ") VALUES(";
  query += Array.from(columnNames.keys())
    .map((element) => "$" + (element + 1))
    .join(",");
  query += ")";

  //console.log(query);
  //console.log(values);

  //Convert empty strings to null values
  values = values.map((value) => (value === "" ? null : value));

  return await db.query(query, values);
}

async function insertSetOfValues(tableName, columnNames, values) {
  let promises = values.map(async function (value) {
    return await insertValues(tableName, columnNames, value);
  });

  return await Promise.all(promises);
}

async function dropForeignKey(tableOrigin, name) {
  let query = "ALTER TABLE IF EXISTS ";
  query += tableOrigin;
  query += " DROP CONSTRAINT IF EXISTS ";
  query += name;

  logger.debug(query);
  return await db.query(query);
}

async function createForeignKey(
  tableOrigin,
  foreignKey,
  tableForeign,
  primaryKey,
  number = 1
) {
  let query = "ALTER TABLE IF EXISTS ";
  query += tableOrigin;
  query += " ADD CONSTRAINT ";
  query += generateForeignKeyName(tableOrigin, tableForeign, number);
  query += " FOREIGN KEY (";
  query += foreignKey;
  query += ") REFERENCES ";
  query += tableForeign;
  query += " (";
  query += primaryKey;
  query += ") ON DELETE CASCADE ON UPDATE CASCADE";

  logger.debug(query);
  return await db.query(query);
}

async function createIndex(table, columnNames) {
  let query = "CREATE INDEX ON ";
  query += table;
  query += "(";
  query += columnNames;
  query += ")";

  logger.debug(query);
  return await db.query(query);
}

function generateForeignKeyName(tableOrigin, tableForeign, number) {
  return tableOrigin + "_" + tableForeign + "_fk" + number;
}

async function dropListOfForeignKeys(listOfForeignKeys) {
  let promises = listOfForeignKeys.map(async function (foreignKey) {
    return await dropForeignKey(
      foreignKey[0],
      generateForeignKeyName(foreignKey[0], foreignKey[2], 1)
    );
  });

  return await Promise.all(promises);
}

async function createListOfForeignKeys(listOfForeignKeys) {
  let promises = listOfForeignKeys.map(async function (foreignKey) {
    return await createForeignKey(...foreignKey);
  });

  return await Promise.all(promises);
}

async function createListOfIndexes(listOfIndexes) {
  let promises = listOfIndexes.map(async function (indexInfo) {
    return await createIndex(...indexInfo);
  });

  return await Promise.all(promises);
}

module.exports = {
  createTable,
  deleteTable,
  insertValues,
  insertSetOfValues,
  createForeignKey,
  createIndex,
  createListOfForeignKeys,
  createListOfIndexes,
  dropListOfForeignKeys,
};
