const showdown = require("showdown");

const converter = new showdown.Converter();

function markdownfyText(text) {
  return converter.makeHtml(text);
}

function markdownfyList(array, indexes) {
  indexes.forEach((index) => (array[index] = markdownfyText(array[index])));
  return array;
}

//(() => {
//  const text = markdownfyText(
//    "# this is a header\n\n completed in:\n\n - First item"
//  );
//  console.log(text);
//
//  const array = ["# header 1", "# header 2", "# header 3"];
//  console.log(markdownfyList(array, [0, 2]));
//})();

module.exports = {
  markdownfyText,
  markdownfyList,
};
