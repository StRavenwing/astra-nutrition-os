import { FileBlob, SpreadsheetFile } from "@oai/artifact-tool";
const input = await FileBlob.load("C:/Users/hell/Downloads/Таблица учета клиентов new.xlsx");
const workbook = await SpreadsheetFile.importXlsx(input);
for (const sheet of workbook.worksheets.items) console.log(JSON.stringify(sheet.name));
