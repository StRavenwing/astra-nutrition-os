import fs from "node:fs/promises";
import { FileBlob, SpreadsheetFile } from "@oai/artifact-tool";

const inputPath = "C:/Users/hell/Downloads/Таблица учета клиентов new.xlsx";
const outputDir = "./outputs/inspect-client-workbook";
await fs.mkdir(outputDir, { recursive: true });

const input = await FileBlob.load(inputPath);
const workbook = await SpreadsheetFile.importXlsx(input);

const summary = await workbook.inspect({
  kind: "workbook,sheet,table,definedName,drawing",
  maxChars: 12000,
  tableMaxRows: 8,
  tableMaxCols: 12,
  tableMaxCellChars: 100,
});
console.log("SUMMARY");
console.log(summary.ndjson);

const sheets = workbook.worksheets.items;
for (const sheet of sheets) {
  const name = sheet.name;
  console.log(`SHEET ${name}`);
  const used = sheet.getUsedRange();
  if (used) {
    console.log("USED_VALUES");
    console.log(JSON.stringify(used.values));
    console.log("USED_FORMULAS");
    console.log(JSON.stringify(used.formulas));
  }
  const preview = await workbook.render({ sheetName: name, autoCrop: "all", scale: 1, format: "png" });
  const safe = name.replace(/[\\/:*?"<>|]/g, "_");
  await fs.writeFile(`${outputDir}/${safe}.png`, new Uint8Array(await preview.arrayBuffer()));
}
