class OptionError extends Error {
  constructor(...params) {
    super(...params);
    if (Error.captureStackTrace) {
      Error.captureStackTrace(this, OptionError);
    }
    this.name = "OptionError";
  }
}

module.exports = {
  OptionError,
};
