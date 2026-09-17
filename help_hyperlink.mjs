import { FileBlob, SpreadsheetFile } from "@oai/artifact-tool";
const input = await FileBlob.load("C:/Users/hell/Downloads/Таблица учета клиентов new.xlsx");
const workbook = await SpreadsheetFile.importXlsx(input);
console.log(workbook.help("hyperlink", { include: "index,examples,notes", maxChars: 5000 }).ndjson);
