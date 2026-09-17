import { FileBlob, SpreadsheetFile } from "@oai/artifact-tool";

const outputPath = "./outputs/client-product-mockup/Таблица учета клиентов — макет приложения.xlsx";
const input = await FileBlob.load(outputPath);
const workbook = await SpreadsheetFile.importXlsx(input);
const clientIndex = workbook.worksheets.getItem("Клиенты");
const annaSheet = workbook.worksheets.getItem("Клиент · Анна");
console.log("KEY_FORMULAS");
console.log(JSON.stringify({
  tile: clientIndex.getRange("A9").formulas,
  tileLink: clientIndex.getRange("N19").formulas,
  delta: annaSheet.getRange("D11").formulas,
  focus: annaSheet.getRange("M11").formulas,
}));

console.log("SHEETS");
console.log((await workbook.inspect({ kind: "sheet", include: "id,name", maxChars: 6000 })).ndjson);
console.log("CLIENT_INDEX");
console.log((await workbook.inspect({ kind: "table", sheetId: "Клиенты", range: "A1:N27", tableMaxRows: 27, tableMaxCols: 14, tableMaxCellChars: 120, maxChars: 12000 })).ndjson);
console.log("CLIENT_CARD");
console.log((await workbook.inspect({ kind: "table", sheetId: "Клиент · Анна", range: "A1:N34", tableMaxRows: 34, tableMaxCols: 14, tableMaxCellChars: 120, maxChars: 16000 })).ndjson);
console.log("FORMULA_ERRORS");
console.log((await workbook.inspect({ kind: "match", searchTerm: "#REF!|#DIV/0!|#VALUE!|#NAME\\?|#N/A|#NUM!|#NULL!|#SPILL!|#CALC!", options: { useRegex: true, maxResults: 300 }, summary: "saved workbook formula error scan" })).ndjson);
