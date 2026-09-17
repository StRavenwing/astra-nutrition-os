import fs from "node:fs/promises";
import { FileBlob, SpreadsheetFile } from "@oai/artifact-tool";

const inputPath = "C:/Users/hell/Downloads/Таблица учета клиентов new.xlsx";
const outputDir = "./outputs/client-product-mockup";
const outputPath = `${outputDir}/Таблица учета клиентов — макет приложения.xlsx`;
const fontName = "Arial";

const colors = {
  navy: "#0F172A",
  blue: "#2563EB",
  blueSoft: "#EFF6FF",
  teal: "#0F766E",
  orange: "#F59E0B",
  orangeSoft: "#FFF7ED",
  green: "#DCFCE7",
  greenText: "#166534",
  amber: "#FEF3C7",
  amberText: "#92400E",
  redSoft: "#FEE2E2",
  redText: "#991B1B",
  text: "#1F2937",
  muted: "#64748B",
  line: "#CBD5E1",
  lineSoft: "#E2E8F0",
  white: "#FFFFFF",
  calc: "#F1F5F9",
};

const clients = [
  {
    id: "C-001",
    sheet: "Клиент · Анна",
    name: "Анна Петрова",
    goal: "Снижение веса",
    status: "Активный",
    nextContact: new Date("2026-09-15T00:00:00Z"),
    startDate: new Date("2026-08-18T00:00:00Z"),
    startWeight: 82.5,
    currentWeight: 79.8,
    targetWeight: 74.0,
    steps: 8600,
    targetSteps: 9000,
    adherence: 0.82,
    calories: 1850,
    protein: 120,
    fat: 65,
    carbs: 180,
    measurements: [
      ["Вес", 82.5, 79.8, 74.0, "кг"],
      ["Грудь", 98, 95, 94, "см"],
      ["Живот", 84, 78, 76, "см"],
      ["Таз", 108, 103, 100, "см"],
      ["Бедро", 62, 59, 57, "см"],
    ],
    tasks: [
      ["Заполнить дневник питания", "Сделано", new Date("2026-09-12T00:00:00Z"), "3 дня записей готовы"],
      ["Снять замеры и фото", "В работе", new Date("2026-09-14T00:00:00Z"), "Напомнить утром"],
      ["Выслать отчет за неделю", "Не начато", new Date("2026-09-15T00:00:00Z"), "После заполнения шагов"],
      ["Проверить средние шаги", "Сделано", new Date("2026-09-11T00:00:00Z"), "Среднее 8 600"],
      ["Согласовать план на неделю", "В работе", new Date("2026-09-16T00:00:00Z"), "Обсудить на созвоне"],
    ],
    contacts: [
      [new Date("2026-09-08T00:00:00Z"), "Мессенджер", "Разобрали дневник питания и режим сна."],
      [new Date("2026-09-01T00:00:00Z"), "Созвон", "Сверили шаги, добавили прогулку после обеда."],
    ],
    note: "Хорошая динамика по объёмам. На следующем контакте проверить сон и регулярность завтрака.",
  },
  {
    id: "C-002",
    sheet: "Клиент · Ирина",
    name: "Ирина Смирнова",
    goal: "Набор мышц",
    status: "Активный",
    nextContact: new Date("2026-09-17T00:00:00Z"),
    startDate: new Date("2026-08-11T00:00:00Z"),
    startWeight: 61.2,
    currentWeight: 62.1,
    targetWeight: 64.0,
    steps: 7200,
    targetSteps: 8000,
    adherence: 0.91,
    calories: 2200,
    protein: 130,
    fat: 70,
    carbs: 250,
    measurements: [
      ["Вес", 61.2, 62.1, 64.0, "кг"],
      ["Грудь", 86, 88, 90, "см"],
      ["Живот", 70, 71, 72, "см"],
      ["Таз", 94, 96, 98, "см"],
      ["Бедро", 53, 55, 57, "см"],
    ],
    tasks: [
      ["Заполнить дневник питания", "Сделано", new Date("2026-09-12T00:00:00Z"), "Данные внесены"],
      ["Силовая тренировка", "В работе", new Date("2026-09-13T00:00:00Z"), "2 тренировки из 3"],
      ["Выслать отчет за неделю", "В работе", new Date("2026-09-17T00:00:00Z"), "Ждем воскресный отчет"],
      ["Проверить белок", "Сделано", new Date("2026-09-11T00:00:00Z"), "120–130 г в день"],
      ["Согласовать прогрессию нагрузки", "Не начато", new Date("2026-09-18T00:00:00Z"), "На следующем созвоне"],
    ],
    contacts: [
      [new Date("2026-09-09T00:00:00Z"), "Мессенджер", "Уточнили белок и восстановление после тренировок."],
      [new Date("2026-09-03T00:00:00Z"), "Созвон", "Добавили дополнительный прием пищи."],
    ],
    note: "Вес растет плавно, соблюдение плана высокое. Следить за восстановлением после силовых.",
  },
  {
    id: "C-003",
    sheet: "Клиент · Мария",
    name: "Мария Волкова",
    goal: "Восстановление режима",
    status: "На паузе",
    nextContact: new Date("2026-09-20T00:00:00Z"),
    startDate: new Date("2026-08-25T00:00:00Z"),
    startWeight: 74.0,
    currentWeight: 74.8,
    targetWeight: 70.0,
    steps: 4500,
    targetSteps: 8000,
    adherence: 0.48,
    calories: 1750,
    protein: 100,
    fat: 60,
    carbs: 180,
    measurements: [
      ["Вес", 74.0, 74.8, 70.0, "кг"],
      ["Грудь", 94, 94, 92, "см"],
      ["Живот", 82, 84, 78, "см"],
      ["Таз", 106, 107, 101, "см"],
      ["Бедро", 61, 62, 58, "см"],
    ],
    tasks: [
      ["Заполнить дневник питания", "Не начато", new Date("2026-09-20T00:00:00Z"), "Возобновить после контакта"],
      ["Снять замеры и фото", "Не начато", new Date("2026-09-21T00:00:00Z"), "Только после согласования"],
      ["Выслать отчет за неделю", "Не начато", new Date("2026-09-22T00:00:00Z"), "Нужно связаться"],
      ["Проверить средние шаги", "В работе", new Date("2026-09-19T00:00:00Z"), "Ниже цели"],
      ["Согласовать новый ритм", "Не начато", new Date("2026-09-23T00:00:00Z"), "Обсудить причины паузы"],
    ],
    contacts: [
      [new Date("2026-09-05T00:00:00Z"), "Мессенджер", "Клиент попросила паузу из-за загрузки на работе."],
      [new Date("2026-08-29T00:00:00Z"), "Созвон", "Определили минимальный план на неделю."],
    ],
    note: "Сейчас важнее восстановить контакт и простой ритм действий. Не перегружать задачами.",
  },
];

function setFont(range, size = 10, color = colors.text, bold = false, italic = false) {
  range.format.font = { name: fontName, size, color, bold, italic };
}

function fill(range, color) {
  range.format.fill = color;
}

function border(range, preset = "all", style = "thin", color = colors.lineSoft) {
  range.format.borders = { preset, style, color };
}

function align(range, horizontal = "left", vertical = "center", wrap = false) {
  range.format.horizontalAlignment = horizontal;
  range.format.verticalAlignment = vertical;
  range.format.wrapText = wrap;
}

function mergeWrite(sheet, address, value, isFormula = false) {
  sheet.mergeCells(address);
  const topLeft = address.split(":")[0];
  if (isFormula) sheet.getRange(topLeft).formulas = [[value]];
  else sheet.getRange(topLeft).values = [[value]];
}

function sectionBand(sheet, address, text) {
  mergeWrite(sheet, address, text);
  const r = sheet.getRange(address);
  fill(r, colors.navy);
  setFont(r, 10, colors.white, true);
  align(r, "left", "center", false);
  border(r, "outside", "thin", colors.navy);
}

function styleInput(sheet, address, numberFormat = null) {
  const r = sheet.getRange(address);
  fill(r, colors.orangeSoft);
  border(r, "all", "thin", colors.line);
  setFont(r, 10, colors.text, false);
  align(r, "left", "center", true);
  if (numberFormat) r.format.numberFormat = numberFormat;
}

function styleCalc(sheet, address, numberFormat = null) {
  const r = sheet.getRange(address);
  fill(r, colors.calc);
  border(r, "all", "thin", colors.lineSoft);
  setFont(r, 10, colors.text, true);
  align(r, "center", "center", true);
  if (numberFormat) r.format.numberFormat = numberFormat;
}

function addPortalLink(sheet, address, label) {
  mergeWrite(sheet, address, '=HYPERLINK("#\'Клиенты\'!A1","← Клиенты")', true);
  const r = sheet.getRange(address);
  fill(r, colors.navy);
  setFont(r, 10, colors.white, true);
  align(r, "center", "center", true);
  border(r, "outside", "thin", colors.navy);
}

function addSheetLink(sheet, address, targetSheet, label) {
  mergeWrite(sheet, address, `=HYPERLINK("#'${targetSheet}'!A1","${label}")`, true);
  const r = sheet.getRange(address);
  fill(r, colors.blue);
  setFont(r, 10, colors.white, true);
  align(r, "center", "center", true);
  border(r, "outside", "thin", colors.blue);
}

function setColumnWidths(sheet, widths) {
  for (const [col, width] of Object.entries(widths)) {
    sheet.getRange(`${col}:${col}`).format.columnWidth = width;
  }
}

function applyStatusFormatting(range) {
  range.conditionalFormats.add("containsText", {
    text: "Активный",
    format: { fill: colors.green, font: { color: colors.greenText, bold: true } },
  });
  range.conditionalFormats.add("containsText", {
    text: "На паузе",
    format: { fill: colors.amber, font: { color: colors.amberText, bold: true } },
  });
  range.conditionalFormats.add("containsText", {
    text: "Завершен",
    format: { fill: colors.lineSoft, font: { color: colors.muted, bold: true } },
  });
}

function applyTaskFormatting(range) {
  range.conditionalFormats.add("containsText", {
    text: "Сделано",
    format: { fill: colors.green, font: { color: colors.greenText, bold: true } },
  });
  range.conditionalFormats.add("containsText", {
    text: "В работе",
    format: { fill: colors.blueSoft, font: { color: colors.blue, bold: true } },
  });
  range.conditionalFormats.add("containsText", {
    text: "Не начато",
    format: { fill: colors.amber, font: { color: colors.amberText, bold: true } },
  });
}

function buildClientSheet(sheet, client) {
  sheet.showGridLines = false;
  sheet.tabColor = colors.blue;
  setColumnWidths(sheet, {
    A: 24, B: 15, C: 13, D: 15, E: 15, F: 15, G: 17,
    H: 18, I: 12, J: 12, K: 12, L: 14, M: 14, N: 24,
  });
  sheet.getRange("A1:N34").format.font = { name: fontName, size: 10, color: colors.text };
  sheet.getRange("A1:N34").format.verticalAlignment = "center";

  mergeWrite(sheet, "A1:N1", '=HYPERLINK("#\'Клиенты\'!A1","← Все клиенты")', true);
  fill(sheet.getRange("A1:N1"), colors.navy);
  setFont(sheet.getRange("A1:N1"), 10, colors.white, true);
  align(sheet.getRange("A1:N1"), "left", "center", false);
  sheet.getRange("A1:N1").format.rowHeight = 24;

  mergeWrite(sheet, "A2:N2", `${client.name}  ·  карточка клиента`);
  setFont(sheet.getRange("A2:N2"), 18, colors.navy, true);
  align(sheet.getRange("A2:N2"), "left", "center", false);
  sheet.getRange("A2:N2").format.rowHeight = 30;

  mergeWrite(sheet, "A3:N3", "Демо-данные для прототипа · желтые поля — ввод специалиста · серые поля — расчеты");
  setFont(sheet.getRange("A3:N3"), 9, colors.muted, false, true);
  align(sheet.getRange("A3:N3"), "left", "center", false);

  sectionBand(sheet, "A5:N5", "Профиль и контроль");
  mergeWrite(sheet, "A6:B6", "Статус");
  mergeWrite(sheet, "D6:F6", "Цель");
  mergeWrite(sheet, "K6:L6", "Следующий контакт");
  setFont(sheet.getRange("A6:B6"), 10, colors.muted, true);
  setFont(sheet.getRange("D6:F6"), 10, colors.muted, true);
  setFont(sheet.getRange("K6:L6"), 10, colors.muted, true);
  align(sheet.getRange("A6:N6"), "left", "center", false);

  mergeWrite(sheet, "A7:B7", client.status);
  mergeWrite(sheet, "D7:J7", client.goal);
  mergeWrite(sheet, "K7:N7", client.nextContact);
  styleInput(sheet, "A7:B7");
  styleInput(sheet, "D7:J7");
  styleInput(sheet, "K7:N7", "yyyy-mm-dd");
  sheet.getRange("A7").dataValidation = { rule: { type: "list", values: ["Активный", "На паузе", "Завершен"] } };
  applyStatusFormatting(sheet.getRange("A7:B7"));

  sectionBand(sheet, "A9:N9", "Ключевые показатели");
  mergeWrite(sheet, "A10:C10", "Вес сейчас (кг)");
  mergeWrite(sheet, "D10:F10", "Изменение к старту");
  mergeWrite(sheet, "G10:I10", "Шаги / день");
  mergeWrite(sheet, "J10:L10", "Соблюдение плана");
  mergeWrite(sheet, "M10:N10", "Фокус недели");
  setFont(sheet.getRange("A10:N10"), 9, colors.muted, true);
  align(sheet.getRange("A10:N10"), "center", "center", true);
  sheet.getRange("A10:N10").format.rowHeight = 24;

  mergeWrite(sheet, "A11:C12", client.currentWeight);
  mergeWrite(sheet, "D11:F12", "=A11-C15", true);
  mergeWrite(sheet, "G11:I12", client.steps);
  mergeWrite(sheet, "J11:L12", client.adherence);
  mergeWrite(sheet, "M11:N12", '=IF(A7="На паузе","Возобновить контакт","Держать ритм")', true);
  styleInput(sheet, "A11:C12", "0.0");
  styleCalc(sheet, "D11:F12", "0.0");
  styleInput(sheet, "G11:I12", "#,##0");
  styleInput(sheet, "J11:L12", "0%");
  styleCalc(sheet, "M11:N12");
  sheet.getRange("A11:N12").format.rowHeight = 24;

  sectionBand(sheet, "A14:F14", "Основные параметры");
  sheet.getRange("A15:B18").values = [
    ["Стартовый вес (кг)", null],
    ["Калории / день", null],
    ["Белки (г)", null],
    ["Углеводы (г)", null],
  ];
  sheet.getRange("D15:E18").values = [
    ["Целевой вес (кг)", null],
    ["Целевые шаги / день", null],
    ["Жиры (г)", null],
    ["Дата старта", null],
  ];
  setFont(sheet.getRange("A15:B18"), 10, colors.muted, true);
  setFont(sheet.getRange("D15:E18"), 10, colors.muted, true);
  align(sheet.getRange("A15:E18"), "left", "center", true);
  sheet.getRange("C15:C18").values = [[client.startWeight], [client.calories], [client.protein], [client.carbs]];
  sheet.getRange("F15:F18").values = [[client.targetWeight], [client.targetSteps], [client.fat], [client.startDate]];
  styleInput(sheet, "C15:C18");
  styleInput(sheet, "F15:F17");
  styleInput(sheet, "F18", "yyyy-mm-dd");
  sheet.getRange("C15").format.numberFormat = "0.0";
  sheet.getRange("F15").format.numberFormat = "0.0";
  sheet.getRange("C16:F17").format.numberFormat = "#,##0";
  border(sheet.getRange("A15:F18"), "all", "thin", colors.lineSoft);

  sectionBand(sheet, "H14:N14", "Прогресс замеров");
  sheet.getRange("H15:N15").values = [["Показатель", "Старт", "Сейчас", "Δ", "Цель", "Ед.", "Контроль"]];
  fill(sheet.getRange("H15:N15"), colors.blueSoft);
  setFont(sheet.getRange("H15:N15"), 9, colors.navy, true);
  align(sheet.getRange("H15:N15"), "center", "center", true);
  sheet.getRange("H15:N15").format.rowHeight = 26;
  const measurementValues = client.measurements.map((m, idx) => [m[0], m[1], m[2], null, m[3], m[4], null]);
  sheet.getRange("H16:N20").values = measurementValues;
  sheet.getRange("K16:K20").formulas = [["=J16-I16"], ["=J17-I17"], ["=J18-I18"], ["=J19-I19"], ["=J20-I20"]];
  sheet.getRange("N16:N20").formulas = [
    ['=IF(ABS(K16)<=1,"Стабильно","Есть изменение")'],
    ['=IF(ABS(K17)<=1,"Стабильно","Есть изменение")'],
    ['=IF(ABS(K18)<=1,"Стабильно","Есть изменение")'],
    ['=IF(ABS(K19)<=1,"Стабильно","Есть изменение")'],
    ['=IF(ABS(K20)<=1,"Стабильно","Есть изменение")'],
  ];
  border(sheet.getRange("H15:N20"), "all", "thin", colors.lineSoft);
  align(sheet.getRange("H16:N20"), "center", "center", true);
  sheet.getRange("I16:L20").format.numberFormat = "0.0";
  sheet.getRange("H16:H20").format.horizontalAlignment = "left";
  sheet.getRange("M16:M20").format.horizontalAlignment = "center";
  styleCalc(sheet, "K16:K20", "0.0");

  sectionBand(sheet, "A22:D22", "План на ближайшие 7 дней");
  sheet.getRange("A23:D23").values = [["Задача", "Статус", "Срок", "Комментарий"]];
  fill(sheet.getRange("A23:D23"), colors.blueSoft);
  setFont(sheet.getRange("A23:D23"), 9, colors.navy, true);
  align(sheet.getRange("A23:D23"), "center", "center", true);
  sheet.getRange("A24:D28").values = client.tasks;
  sheet.getRange("C24:C28").format.numberFormat = "yyyy-mm-dd";
  border(sheet.getRange("A23:D28"), "all", "thin", colors.lineSoft);
  align(sheet.getRange("A24:D28"), "left", "center", true);
  sheet.getRange("B24:B28").format.horizontalAlignment = "center";
  sheet.getRange("C24:C28").format.horizontalAlignment = "center";
  sheet.getRange("B24:B28").dataValidation = { rule: { type: "list", values: ["Сделано", "В работе", "Не начато"] } };
  applyTaskFormatting(sheet.getRange("B24:B28"));
  sheet.getRange("A24:A28").format.columnWidth = 28;
  sheet.getRange("D24:D28").format.columnWidth = 34;

  sectionBand(sheet, "F22:N22", "Контакты и заметки");
  sheet.getRange("F23:H23").values = [["Дата", "Канал", "Итог"]];
  fill(sheet.getRange("F23:H23"), colors.blueSoft);
  setFont(sheet.getRange("F23:H23"), 9, colors.navy, true);
  align(sheet.getRange("F23:H23"), "center", "center", true);
  sheet.getRange("F24:H25").values = client.contacts;
  sheet.getRange("F24:F25").format.numberFormat = "yyyy-mm-dd";
  border(sheet.getRange("F23:H25"), "all", "thin", colors.lineSoft);
  align(sheet.getRange("F24:H25"), "left", "center", true);
  sheet.getRange("F24:F25").format.horizontalAlignment = "center";
  mergeWrite(sheet, "F26:N26", "Заметка специалиста");
  setFont(sheet.getRange("F26:N26"), 9, colors.muted, true);
  mergeWrite(sheet, "F27:N28", client.note);
  styleInput(sheet, "F27:N28");
  align(sheet.getRange("F27:N28"), "left", "top", true);

  sectionBand(sheet, "A30:N30", "Рабочие вкладки");
  addSheetLink(sheet, "A31:C32", "ТОЧКИ А-Б", "Открыть замеры");
  addSheetLink(sheet, "D31:F32", "Питание и активность", "Открыть питание");
  addSheetLink(sheet, "G31:I32", "1 НЕДЕЛЯ ", "Открыть неделю 1");
  addSheetLink(sheet, "J31:L32", " 2 НЕДЕЛЯ ", "Открыть неделю 2");
  addSheetLink(sheet, "M31:N32", "Клиенты", "← К списку");
  mergeWrite(sheet, "A34:N34", "Источники данных прототипа: исходные вкладки книги «ТОЧКИ А-Б», «Питание и активность», «1 НЕДЕЛЯ», «2 НЕДЕЛЯ»." );
  setFont(sheet.getRange("A34:N34"), 9, colors.muted, false, true);
  align(sheet.getRange("A34:N34"), "left", "center", true);

  sheet.freezePanes.freezeRows(4);
}

const input = await FileBlob.load(inputPath);
const workbook = await SpreadsheetFile.importXlsx(input);

const clientsSheet = workbook.worksheets.add("Клиенты");
clientsSheet.showGridLines = false;
clientsSheet.tabColor = colors.orange;
setColumnWidths(clientsSheet, { A: 24, B: 14, C: 14, D: 14, E: 3, F: 24, G: 14, H: 14, I: 14, J: 3, K: 24, L: 14, M: 14, N: 14 });
clientsSheet.getRange("A1:N30").format.font = { name: fontName, size: 10, color: colors.text };

mergeWrite(clientsSheet, "A1:N1", "Клиенты");
setFont(clientsSheet.getRange("A1:N1"), 20, colors.navy, true);
align(clientsSheet.getRange("A1:N1"), "left", "center", false);
clientsSheet.getRange("A1:N1").format.rowHeight = 30;
mergeWrite(clientsSheet, "A2:N2", "Рабочее пространство специалиста · макет продукта на основе исходной таблицы");
setFont(clientsSheet.getRange("A2:N2"), 10, colors.muted, false, true);
align(clientsSheet.getRange("A2:N2"), "left", "center", false);
mergeWrite(clientsSheet, "A3:N3", "Демонстрационные записи: плитка открывает карточку клиента, карточка ведет в исходные рабочие вкладки.");
setFont(clientsSheet.getRange("A3:N3"), 9, colors.muted, false, true);
align(clientsSheet.getRange("A3:N3"), "left", "center", false);

const kpiLabels = ["Всего клиентов", "Активные", "На паузе", "Требуют внимания"];
const kpiRanges = ["A5:C5", "D5:F5", "G5:I5", "J5:N5"];
const kpiValueRanges = ["A6:C6", "D6:F6", "G6:I6", "J6:N6"];
for (let i = 0; i < kpiLabels.length; i++) {
  mergeWrite(clientsSheet, kpiRanges[i], kpiLabels[i]);
  fill(clientsSheet.getRange(kpiRanges[i]), colors.navy);
  setFont(clientsSheet.getRange(kpiRanges[i]), 9, colors.white, true);
  align(clientsSheet.getRange(kpiRanges[i]), "center", "center", true);
  fill(clientsSheet.getRange(kpiValueRanges[i]), colors.calc);
  border(clientsSheet.getRange(kpiValueRanges[i]), "outside", "thin", colors.line);
  setFont(clientsSheet.getRange(kpiValueRanges[i]), 18, colors.navy, true);
  align(clientsSheet.getRange(kpiValueRanges[i]), "center", "center", false);
}
clientsSheet.getRange("A6").formulas = [["=COUNTA($A$19:$A$21)"]];
clientsSheet.getRange("D6").formulas = [["=COUNTIF($C$19:$C$21,\"Активный\")"]];
clientsSheet.getRange("G6").formulas = [["=COUNTIF($C$19:$C$21,\"На паузе\")"]];
clientsSheet.getRange("J6").formulas = [["=COUNTIF($L$19:$L$21,\"Требует внимания\")"]];

sectionBand(clientsSheet, "A8:N8", "Плитки клиентов");
const tileRanges = ["A9:D15", "F9:I15", "K9:N15"];
for (let i = 0; i < clients.length; i++) {
  const c = clients[i];
  const tile = tileRanges[i];
  const formula = `=HYPERLINK("#'${c.sheet}'!A1",${JSON.stringify(c.name)}&CHAR(10)&${JSON.stringify(c.goal)}&CHAR(10)&"Статус: "&'${c.sheet}'!A7)`;
  mergeWrite(clientsSheet, tile, formula, true);
  fill(clientsSheet.getRange(tile), i === 2 ? colors.amber : colors.blue);
  setFont(clientsSheet.getRange(tile), 13, i === 2 ? colors.amberText : colors.white, true);
  align(clientsSheet.getRange(tile), "left", "center", true);
  border(clientsSheet.getRange(tile), "outside", "medium", i === 2 ? colors.orange : colors.blue);
  clientsSheet.getRange(tile).format.rowHeight = 24;
}

sectionBand(clientsSheet, "A17:N17", "Реестр клиентов (демо)");
clientsSheet.getRange("A18:N18").values = [["ID", "Клиент", "Статус", "Цель", "Дата старта", "Следующий контакт", "Старт, кг", "Сейчас, кг", "Δ, кг", "Шаги", "Соблюдение", "Контроль", "Последний фокус", "Карточка"]];
fill(clientsSheet.getRange("A18:N18"), colors.navy);
setFont(clientsSheet.getRange("A18:N18"), 9, colors.white, true);
align(clientsSheet.getRange("A18:N18"), "center", "center", true);
clientsSheet.getRange("A18:N18").format.rowHeight = 30;
clientsSheet.getRange("A19:B21").values = clients.map(c => [c.id, c.name]);
clientsSheet.getRange("C19:C21").formulas = clients.map(c => [`='${c.sheet}'!A7`]);
clientsSheet.getRange("D19:D21").formulas = clients.map(c => [`='${c.sheet}'!D7`]);
clientsSheet.getRange("E19:E21").formulas = clients.map(c => [`='${c.sheet}'!F18`]);
clientsSheet.getRange("F19:F21").formulas = clients.map(c => [`='${c.sheet}'!K7`]);
clientsSheet.getRange("G19:G21").formulas = clients.map(c => [`='${c.sheet}'!C15`]);
clientsSheet.getRange("H19:H21").formulas = clients.map(c => [`='${c.sheet}'!A11`]);
clientsSheet.getRange("I19:I21").formulas = [["=H19-G19"], ["=H20-G20"], ["=H21-G21"]];
clientsSheet.getRange("J19:J21").formulas = clients.map(c => [`='${c.sheet}'!G11`]);
clientsSheet.getRange("K19:K21").formulas = clients.map(c => [`='${c.sheet}'!J11`]);
clientsSheet.getRange("L19:L21").formulas = [["=IF(C19=\"На паузе\",\"Требует внимания\",\"В норме\")"], ["=IF(C20=\"На паузе\",\"Требует внимания\",\"В норме\")"], ["=IF(C21=\"На паузе\",\"Требует внимания\",\"В норме\")"]];
clientsSheet.getRange("M19:M21").formulas = [["=IF(C19=\"На паузе\",\"Возобновить контакт\",\"Держать ритм\")"], ["=IF(C20=\"На паузе\",\"Держать прогрессию\",\"Держать ритм\")"], ["=IF(C21=\"На паузе\",\"Вернуть контакт\",\"Держать ритм\")"]];
clientsSheet.getRange("N19:N21").formulas = clients.map(c => [`=HYPERLINK("#'${c.sheet}'!A1","Открыть")`]);
border(clientsSheet.getRange("A18:N21"), "all", "thin", colors.lineSoft);
align(clientsSheet.getRange("A19:N21"), "left", "center", true);
clientsSheet.getRange("A19:A21").format.horizontalAlignment = "center";
clientsSheet.getRange("C19:C21").format.horizontalAlignment = "center";
clientsSheet.getRange("E19:F21").format.numberFormat = "yyyy-mm-dd";
clientsSheet.getRange("G19:I21").format.numberFormat = "0.0";
clientsSheet.getRange("J19:J21").format.numberFormat = "#,##0";
clientsSheet.getRange("K19:K21").format.numberFormat = "0%";
clientsSheet.getRange("N19:N21").format.horizontalAlignment = "center";
applyStatusFormatting(clientsSheet.getRange("C19:C21"));
clientsSheet.getRange("L19:L21").conditionalFormats.add("containsText", { text: "Требует внимания", format: { fill: colors.redSoft, font: { color: colors.redText, bold: true } } });
clientsSheet.getRange("L19:L21").conditionalFormats.add("containsText", { text: "В норме", format: { fill: colors.green, font: { color: colors.greenText, bold: true } } });

mergeWrite(clientsSheet, "A24:N24", "Легенда: желтый — ввод специалистом · серый — расчет · зеленый — в норме · янтарный/красный — требует внимания");
setFont(clientsSheet.getRange("A24:N24"), 9, colors.muted, false, true);
align(clientsSheet.getRange("A24:N24"), "left", "center", true);
addSheetLink(clientsSheet, "A26:D27", "ТОЧКИ А-Б", "Открыть исходную таблицу");
addSheetLink(clientsSheet, "F26:I27", "Питание и активность", "Открыть питание");
addSheetLink(clientsSheet, "K26:N27", "1 НЕДЕЛЯ ", "Открыть недельный план");
clientsSheet.freezePanes.freezeRows(3);

for (const c of clients) {
  const sheet = workbook.worksheets.add(c.sheet);
  buildClientSheet(sheet, c);
}

const existingSheets = workbook.worksheets.items;
const sourceLinks = [
  ["ТОЧКИ А-Б", "O1:Q2"],
  ["Питание и активность", "J1:L2"],
  ["1 НЕДЕЛЯ ", "I1:K2"],
  [" 2 НЕДЕЛЯ ", "I1:K2"],
];
for (const [sheetName, address] of sourceLinks) {
  const sheet = existingSheets.find(s => s.name === sheetName);
  if (sheet) addPortalLink(sheet, address, "Клиенты");
}

await fs.mkdir(outputDir, { recursive: true });
const output = await SpreadsheetFile.exportXlsx(workbook);
await output.save(outputPath);

console.log(`SAVED ${outputPath}`);
console.log((await workbook.inspect({ kind: "sheet", include: "id,name", maxChars: 6000 })).ndjson);
console.log((await workbook.inspect({ kind: "table", sheetId: "Клиенты", range: "A1:N27", tableMaxRows: 27, tableMaxCols: 14, tableMaxCellChars: 100, maxChars: 12000 })).ndjson);
console.log((await workbook.inspect({ kind: "table", sheetId: "Клиент · Анна", range: "A1:N34", tableMaxRows: 34, tableMaxCols: 14, tableMaxCellChars: 100, maxChars: 16000 })).ndjson);
console.log((await workbook.inspect({ kind: "match", searchTerm: "#REF!|#DIV/0!|#VALUE!|#NAME\\?|#N/A|#NUM!|#NULL!|#SPILL!|#CALC!", options: { useRegex: true, maxResults: 300 }, summary: "final formula error scan" })).ndjson);

for (const sheetName of ["Клиенты", "Клиент · Анна", "Клиент · Ирина", "Клиент · Мария"]) {
  const preview = await workbook.render({ sheetName, autoCrop: "all", scale: 1.2, format: "png" });
  const safe = sheetName.replace(/[\\/:*?"<>|]/g, "_");
  await fs.writeFile(`${outputDir}/${safe}.png`, new Uint8Array(await preview.arrayBuffer()));
}
