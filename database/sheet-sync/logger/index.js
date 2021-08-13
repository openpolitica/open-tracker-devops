const winston = require("winston");
const {
  combine,
  colorize,
  timestamp,
  label,
  printf,
  splat,
  json,
} = winston.format;

const logFormat = printf(({ level, message, label, timestamp }) => {
  return `${timestamp} [${label}] ${level}: ${message}`;
});

const requiredLevels = {
  levels: {
    error: 0,
    warning: 1,
    notice: 2,
    info: 3,
    debug: 4,
  },
  colors: {
    error: "red",
    warning: "yellow",
    notice: "cyan",
    info: "green",
    debug: "grey",
  },
};

const transports = {
  console: new winston.transports.Console({
    format: combine(
      label({ label: "sheet-sync" }),
      colorize({ all: true }),
      timestamp(),
      splat(),
      logFormat
    ),
  }),
  file: new winston.transports.File({
    filename: "combined.log",
    level: "info",
    format: combine(
      label({ label: "sheet-sync" }),
      timestamp(),
      splat(),
      logFormat
    ),
  }),
  file: new winston.transports.File({
    filename: "error.log",
    level: "error",
    format: combine(
      label({ label: "sheet-sync" }),
      timestamp(),
      splat(),
      logFormat
    ),
  }),
};

const logger = winston.createLogger({
  level: "info",
  levels: requiredLevels.levels,
  format: winston.format.json(),
  transports: [transports.console, transports.file],
});

winston.addColors(requiredLevels.colors);

module.exports = { logger, transports };
