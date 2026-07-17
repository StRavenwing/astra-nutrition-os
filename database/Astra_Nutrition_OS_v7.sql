BEGIN TRANSACTION;
CREATE TABLE changelog (
  change_id INTEGER PRIMARY KEY AUTOINCREMENT,
  changed_at TEXT NOT NULL,
  object_id TEXT NOT NULL,
  version TEXT,
  status TEXT,
  change_type TEXT,
  description TEXT,
  author TEXT,
  next_action TEXT
);
INSERT INTO "changelog" VALUES(1,'2026-07-14','WORKBOOK','7.0','Approved','Major','Создана Astra Nutrition OS v7: Dashboard, продукты, рецепты, дневник, прогресс и тренировки','Астра','Добавлять новые фактические цены');
INSERT INTO "changelog" VALUES(2,'2026-07-14','M-001','1.0','Approved','Create','Куриная запеканка без брокколи, 3 порции','Настя + Астра',NULL);
INSERT INTO "changelog" VALUES(3,'2026-07-14','M-002','1.1','Approved','Update','Количество говяжьего фарша изменено на 270 г','Настя + Астра',NULL);
INSERT INTO "changelog" VALUES(4,'2026-07-14','B-001','1.0','Approved','Create','Добавлена яичница с томатами и хлебом Lidl','Настя + Астра','Уточнить КБЖУ хлеба при появлении данных');
INSERT INTO "changelog" VALUES(5,'2026-07-14','D-002','1.1','Approved','Update','Голубичный крем со скиром и старым творогом','Настя + Астра',NULL);
CREATE TABLE exercises (
  exercise_id TEXT PRIMARY KEY,
  muscle_group TEXT,
  name TEXT NOT NULL,
  default_unit TEXT,
  default_sets INTEGER,
  default_reps INTEGER,
  target_rir TEXT,
  note TEXT
);
INSERT INTO "exercises" VALUES('EX-001','Ноги','Жим ногами сидя','кг',3,12,'0–2',NULL);
INSERT INTO "exercises" VALUES('EX-002','Задняя цепь','Румынская тяга','кг',3,12,'0–2',NULL);
INSERT INTO "exercises" VALUES('EX-003','Ягодицы','Разведение ног','кг',3,12,'0–2',NULL);
INSERT INTO "exercises" VALUES('EX-004','Приводящие','Сведение ног','кг',3,12,'0–2',NULL);
INSERT INTO "exercises" VALUES('EX-005','Ягодицы','Отведение ноги','кг',3,12,'0–2',NULL);
INSERT INTO "exercises" VALUES('EX-006','Кор','Пресс-машина','кг',3,12,'0–2',NULL);
INSERT INTO "exercises" VALUES('EX-007','Ягодицы','Ягодичный мост','кг блинов',3,12,'0–2','2 × 15 кг');
INSERT INTO "exercises" VALUES('EX-008','Спина','Вертикальная тяга','кг',3,12,'0–2',NULL);
INSERT INTO "exercises" VALUES('EX-009','Спина','Горизонтальная тяга','кг',3,12,'0–2',NULL);
INSERT INTO "exercises" VALUES('EX-010','Спина','Гиперэкстензия','кг',3,12,'0–2','доп. вес');
INSERT INTO "exercises" VALUES('EX-011','Руки','Бицепс','кг',3,12,'0–2',NULL);
INSERT INTO "exercises" VALUES('EX-012','Грудь','Бабочка','кг',3,12,'0–2',NULL);
INSERT INTO "exercises" VALUES('EX-013','Плечи','Обратная бабочка','кг',3,12,'0–2',NULL);
INSERT INTO "exercises" VALUES('EX-014','Плечи','Жим плечами в тренажере','кг',3,12,'0–2',NULL);
INSERT INTO "exercises" VALUES('EX-015','Плечи/спина','Дельты и широчайшие','кг',3,12,'0–2',NULL);
INSERT INTO "exercises" VALUES('EX-016','Трицепс','Seated Dip Machine','кг',3,12,'0–2',NULL);
INSERT INTO "exercises" VALUES('EX-017','Задняя поверхность бедра','Сгибание ног лежа','кг',3,12,'0–2',NULL);
CREATE TABLE food_diary (
  diary_id INTEGER PRIMARY KEY AUTOINCREMENT,
  entry_date TEXT NOT NULL,
  meal_type TEXT,
  recipe_id TEXT REFERENCES recipes(recipe_id),
  servings REAL NOT NULL DEFAULT 1 CHECK(servings > 0),
  comment TEXT
);
CREATE TABLE products (
  product_id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  category TEXT,
  unit TEXT NOT NULL,
  package_price_rsd REAL CHECK(package_price_rsd IS NULL OR package_price_rsd >= 0),
  package_size REAL CHECK(package_size IS NULL OR package_size > 0),
  price_per_100_or_unit_rsd REAL CHECK(price_per_100_or_unit_rsd IS NULL OR price_per_100_or_unit_rsd >= 0),
  kcal REAL NOT NULL CHECK(kcal >= 0),
  protein_g REAL NOT NULL CHECK(protein_g >= 0),
  fat_g REAL NOT NULL CHECK(fat_g >= 0),
  carbs_g REAL NOT NULL CHECK(carbs_g >= 0),
  data_status TEXT NOT NULL CHECK(data_status IN ('Подтверждено','Оценка')),
  note TEXT
);
INSERT INTO "products" VALUES('P-001','Яйцо','Белковые','шт',20.0,1.0,20.0,72.0,6.3,4.8,0.4,'Подтверждено','10 шт / 200 дин');
INSERT INTO "products" VALUES('P-002','Творог 0,2% (старый)','Молочные','г',202.5,500.0,40.5,66.0,12.0,0.2,4.1,'Подтверждено','500 г / 202,5 дин');
INSERT INTO "products" VALUES('P-003','Творог 0,2% (новый)','Молочные','г',230.0,400.0,57.5,66.0,13.0,0.2,3.0,'Подтверждено','400 г / 230 дин');
INSERT INTO "products" VALUES('P-004','Скир','Молочные','г',226.0,500.0,45.2,62.0,11.0,0.2,4.0,'Подтверждено','500 г / 226 дин');
INSERT INTO "products" VALUES('P-005','Греческий йогурт 2%','Молочные','г',100.0,500.0,20.0,73.0,5.0,2.0,4.0,'Оценка','углеводы и ккал оценочные');
INSERT INTO "products" VALUES('P-006','Маскарпоне 42,5%','Молочные','г',314.0,220.0,142.73,430.0,5.0,42.5,4.0,'Подтверждено','220 г / 314 дин');
INSERT INTO "products" VALUES('P-007','Моцарелла light','Сыры','г',114.0,125.0,91.2,164.0,20.4,8.5,1.5,'Подтверждено','125 г / 114 дин');
INSERT INTO "products" VALUES('P-008','Пармиджано Реджано','Сыры','г',3200.0,1000.0,320.0,400.0,36.0,29.0,4.0,'Оценка','КБЖУ средние');
INSERT INTO "products" VALUES('P-009','Тунец в собственном соку','Рыба','г',140.0,160.0,87.5,116.0,26.0,1.0,0.0,'Подтверждено','1 банка');
INSERT INTO "products" VALUES('P-010','Куриное филе грудки','Мясо','г',NULL,NULL,NULL,110.0,23.0,1.2,0.0,'Оценка','цена не предоставлена');
INSERT INTO "products" VALUES('P-011','Филе куриного бедра','Мясо','г',330.0,780.0,42.31,165.0,19.0,9.0,0.0,'Оценка','КБЖУ средние');
INSERT INTO "products" VALUES('P-012','Куриные желудки','Мясо','г',145.0,450.0,32.22,94.0,18.0,2.0,0.6,'Оценка','КБЖУ средние');
INSERT INTO "products" VALUES('P-013','Креветки королевские в панцире','Морепродукты','г',800.0,400.0,200.0,99.0,24.0,0.3,0.2,'Оценка','в рецепте 400 г покупки ≈200 г мяса');
INSERT INTO "products" VALUES('P-014','Говяжий фарш 7%','Мясо','г',630.0,400.0,157.5,151.0,21.0,7.0,0.0,'Оценка','КБЖУ средние');
INSERT INTO "products" VALUES('P-015','Протеиновая тортилья','Основа','г',180.0,360.0,50.0,279.0,18.0,7.0,37.0,'Подтверждено','КБЖУ на 100 г');
INSERT INTO "products" VALUES('P-016','Паста','Основа','г',140.0,250.0,56.0,311.0,9.8,3.2,52.8,'Подтверждено','КБЖУ на 100 г');
INSERT INTO "products" VALUES('P-017','Рис сухой','Крупы','г',180.0,1000.0,18.0,344.0,7.0,0.6,78.0,'Оценка','КБЖУ средние');
INSERT INTO "products" VALUES('P-018','Киноа сухая','Крупы','г',300.0,350.0,85.71,368.0,14.0,6.0,64.0,'Оценка','КБЖУ средние');
INSERT INTO "products" VALUES('P-019','Перловка Aro сухая','Крупы','г',NULL,NULL,NULL,321.0,9.3,1.1,68.4,'Подтверждено','цена не предоставлена');
INSERT INTO "products" VALUES('P-020','Помидор','Овощи','г',200.0,1000.0,20.0,18.0,0.9,0.2,3.9,'Оценка','КБЖУ средние');
INSERT INTO "products" VALUES('P-021','Огурец','Овощи','г',84.0,400.0,21.0,15.0,0.7,0.1,3.3,'Оценка','КБЖУ средние');
INSERT INTO "products" VALUES('P-022','Баклажан','Овощи','г',230.0,1000.0,23.0,25.0,1.0,0.1,6.0,'Оценка','КБЖУ средние');
INSERT INTO "products" VALUES('P-023','Брокколи','Овощи','г',NULL,NULL,NULL,34.0,2.8,0.4,6.6,'Оценка','цена не предоставлена');
INSERT INTO "products" VALUES('P-024','Голубика','Ягоды','г',NULL,NULL,NULL,57.0,0.7,0.3,14.5,'Оценка','цена не предоставлена');
INSERT INTO "products" VALUES('P-025','Ежевика','Ягоды','г',300.0,350.0,85.71,43.0,1.4,0.5,9.6,'Оценка','КБЖУ средние');
INSERT INTO "products" VALUES('P-026','Кленовый сироп','Добавки','мл',600.0,350.0,171.43,344.0,0.0,0.0,89.6,'Оценка','на 100 мл, 25 мл ≈86 ккал');
INSERT INTO "products" VALUES('P-027','Оливковое масло','Масла','мл',800.0,1000.0,80.0,884.0,0.0,100.0,0.0,'Оценка','1 ч.л. = 5 мл');
INSERT INTO "products" VALUES('P-028','Растительное масло','Масла','мл',NULL,NULL,NULL,884.0,0.0,100.0,0.0,'Оценка','цена не предоставлена');
INSERT INTO "products" VALUES('P-029','Соус для пиццы/пасты','Соусы','г',177.0,360.0,49.17,85.5,1.8,7.0,5.3,'Подтверждено','КБЖУ на 100 г');
INSERT INTO "products" VALUES('P-030','Вяленые томаты в масле','Овощи','г',2500.0,1000.0,250.0,260.0,6.0,16.0,23.0,'Оценка','КБЖУ средние');
INSERT INTO "products" VALUES('P-031','Чеснок','Овощи','г',200.0,300.0,66.67,149.0,6.4,0.5,33.1,'Оценка','КБЖУ средние');
INSERT INTO "products" VALUES('P-032','Укроп / петрушка','Зелень','г',110.0,20.0,550.0,36.0,3.0,0.8,6.0,'Оценка','цена одинаковая');
INSERT INTO "products" VALUES('P-033','Бездрожжевой хлеб Lidl','Хлеб','г',NULL,350.0,NULL,230.0,8.0,2.0,44.0,'Оценка','ломтик ≈25 г; КБЖУ оценочные');
INSERT INTO "products" VALUES('P-034','Фруктово-протеиновый снек','Перекусы','шт',170.0,1.0,170.0,199.0,20.0,3.0,23.0,'Подтверждено','на 1 снек');
INSERT INTO "products" VALUES('P-035','Протеиновый холодный чай','Напитки','бут.',NULL,1.0,NULL,80.0,20.0,0.0,0.0,'Подтверждено','500 мл / бутылка');
CREATE TABLE progress (
  progress_id INTEGER PRIMARY KEY AUTOINCREMENT,
  measured_at TEXT NOT NULL UNIQUE,
  weight_kg REAL,
  waist_cm REAL,
  chest_cm REAL,
  hips_cm REAL,
  height_cm REAL,
  bmi REAL,
  body_fat_pct REAL,
  fat_mass_kg REAL,
  muscle_pct REAL,
  muscle_mass_kg REAL,
  sleep_score INTEGER CHECK(sleep_score BETWEEN 1 AND 5 OR sleep_score IS NULL),
  wellbeing_score INTEGER CHECK(wellbeing_score BETWEEN 1 AND 5 OR wellbeing_score IS NULL),
  comment TEXT
);
INSERT INTO "progress" (progress_id,measured_at,weight_kg,waist_cm,chest_cm,hips_cm,height_cm,bmi,sleep_score,wellbeing_score,comment) VALUES(1,'2025-07-14',78.0,88.0,NULL,NULL,169.0,27.31,NULL,NULL,'Исторический максимум, приблизительно');
INSERT INTO "progress" (progress_id,measured_at,weight_kg,waist_cm,chest_cm,hips_cm,height_cm,bmi,sleep_score,wellbeing_score,comment) VALUES(2,'2026-07-14',73.0,81.0,NULL,NULL,169.0,25.56,NULL,NULL,'Текущая точка');
CREATE TABLE recipe_ingredients (
  recipe_ingredient_id INTEGER PRIMARY KEY AUTOINCREMENT,
  recipe_id TEXT NOT NULL REFERENCES recipes(recipe_id) ON DELETE CASCADE,
  product_id TEXT NOT NULL REFERENCES products(product_id),
  quantity REAL NOT NULL CHECK(quantity >= 0),
  unit TEXT NOT NULL,
  portion_description TEXT,
  UNIQUE(recipe_id, product_id, portion_description)
);
INSERT INTO "recipe_ingredients" VALUES(1,'B-001','P-001',6.0,'шт','6 шт');
INSERT INTO "recipe_ingredients" VALUES(2,'B-001','P-020',300.0,'г','300 г');
INSERT INTO "recipe_ingredients" VALUES(3,'B-001','P-028',15.0,'мл','1 ст.л.');
INSERT INTO "recipe_ingredients" VALUES(4,'B-001','P-032',3.0,'г','3 г');
INSERT INTO "recipe_ingredients" VALUES(5,'B-001','P-033',125.0,'г','5 ломтиков ≈125 г');
INSERT INTO "recipe_ingredients" VALUES(6,'M-001','P-003',200.0,'г','200 г');
INSERT INTO "recipe_ingredients" VALUES(7,'M-001','P-010',400.0,'г','400 г');
INSERT INTO "recipe_ingredients" VALUES(8,'M-001','P-004',60.0,'г','3 ст.л. ≈60 г');
INSERT INTO "recipe_ingredients" VALUES(9,'M-001','P-001',2.0,'шт','2 шт');
INSERT INTO "recipe_ingredients" VALUES(10,'M-001','P-031',7.0,'г','1 зубчик');
INSERT INTO "recipe_ingredients" VALUES(11,'M-001','P-032',1.0,'г','1/2 ч.л. сушеного');
INSERT INTO "recipe_ingredients" VALUES(12,'M-002','P-014',270.0,'г','270 г');
INSERT INTO "recipe_ingredients" VALUES(13,'M-002','P-029',350.0,'г','350 г');
INSERT INTO "recipe_ingredients" VALUES(14,'M-002','P-016',250.0,'г','250 г');
INSERT INTO "recipe_ingredients" VALUES(15,'M-002','P-008',10.0,'г','2 ч.л.');
INSERT INTO "recipe_ingredients" VALUES(16,'M-003','P-015',550.0,'г','тесто: приближено тортильей по данным БЖУ');
INSERT INTO "recipe_ingredients" VALUES(17,'M-003','P-029',400.0,'г','400 г');
INSERT INTO "recipe_ingredients" VALUES(18,'M-003','P-007',125.0,'г','125 г');
INSERT INTO "recipe_ingredients" VALUES(19,'M-003','P-010',250.0,'г','индейка: временно профиль куриного филе');
INSERT INTO "recipe_ingredients" VALUES(20,'M-004','P-010',400.0,'г','400 г');
INSERT INTO "recipe_ingredients" VALUES(21,'M-004','P-003',200.0,'г','200 г');
INSERT INTO "recipe_ingredients" VALUES(22,'M-004','P-001',1.0,'шт','1 шт');
INSERT INTO "recipe_ingredients" VALUES(23,'M-004','P-032',5.0,'г','5 г');
INSERT INTO "recipe_ingredients" VALUES(24,'M-004','P-031',5.0,'г','5 г');
INSERT INTO "recipe_ingredients" VALUES(25,'M-005','P-022',300.0,'г','300 г');
INSERT INTO "recipe_ingredients" VALUES(26,'M-005','P-020',400.0,'г','400 г');
INSERT INTO "recipe_ingredients" VALUES(27,'M-005','P-030',20.0,'г','4 половинки');
INSERT INTO "recipe_ingredients" VALUES(28,'M-005','P-027',5.0,'мл','1 ч.л.');
INSERT INTO "recipe_ingredients" VALUES(29,'M-005','P-007',125.0,'г','125 г');
INSERT INTO "recipe_ingredients" VALUES(30,'M-005','P-016',250.0,'г','250 г');
INSERT INTO "recipe_ingredients" VALUES(31,'M-005','P-008',5.0,'г','1 ч.л.');
INSERT INTO "recipe_ingredients" VALUES(32,'S-001','P-001',2.0,'шт','2 шт');
INSERT INTO "recipe_ingredients" VALUES(33,'S-001','P-009',160.0,'г','1 банка');
INSERT INTO "recipe_ingredients" VALUES(34,'S-001','P-007',125.0,'г','125 г');
INSERT INTO "recipe_ingredients" VALUES(35,'S-001','P-021',150.0,'г','150 г');
INSERT INTO "recipe_ingredients" VALUES(36,'S-001','P-029',60.0,'г','соус 60 г');
INSERT INTO "recipe_ingredients" VALUES(37,'S-002','P-001',2.0,'шт','2 шт');
INSERT INTO "recipe_ingredients" VALUES(38,'S-002','P-011',300.0,'г','300 г сырых');
INSERT INTO "recipe_ingredients" VALUES(39,'S-002','P-007',125.0,'г','125 г');
INSERT INTO "recipe_ingredients" VALUES(40,'S-002','P-021',150.0,'г','150 г');
INSERT INTO "recipe_ingredients" VALUES(41,'S-002','P-029',60.0,'г','соус 60 г');
INSERT INTO "recipe_ingredients" VALUES(42,'S-003','P-001',2.0,'шт','2 шт');
INSERT INTO "recipe_ingredients" VALUES(43,'S-003','P-012',250.0,'г','250 г');
INSERT INTO "recipe_ingredients" VALUES(44,'S-003','P-007',125.0,'г','125 г');
INSERT INTO "recipe_ingredients" VALUES(45,'S-003','P-021',150.0,'г','150 г');
INSERT INTO "recipe_ingredients" VALUES(46,'S-003','P-029',60.0,'г','соус 60 г');
INSERT INTO "recipe_ingredients" VALUES(47,'W-001','P-001',2.0,'шт','2 шт');
INSERT INTO "recipe_ingredients" VALUES(48,'W-001','P-021',150.0,'г','150 г');
INSERT INTO "recipe_ingredients" VALUES(49,'W-001','P-009',160.0,'г','1 банка');
INSERT INTO "recipe_ingredients" VALUES(50,'W-001','P-005',40.0,'г','2 ст.л.');
INSERT INTO "recipe_ingredients" VALUES(51,'W-001','P-032',5.0,'г','5 г');
INSERT INTO "recipe_ingredients" VALUES(52,'W-001','P-002',100.0,'г','4 ст.л.');
INSERT INTO "recipe_ingredients" VALUES(53,'W-001','P-015',160.0,'г','160 г');
INSERT INTO "recipe_ingredients" VALUES(54,'W-002','P-015',160.0,'г','160 г');
INSERT INTO "recipe_ingredients" VALUES(55,'W-002','P-013',400.0,'г','400 г в панцире; покупка целиком');
INSERT INTO "recipe_ingredients" VALUES(56,'W-002','P-002',50.0,'г','2 ст.л.');
INSERT INTO "recipe_ingredients" VALUES(57,'W-002','P-005',20.0,'г','1 ст.л.');
INSERT INTO "recipe_ingredients" VALUES(58,'W-002','P-020',200.0,'г','200 г');
INSERT INTO "recipe_ingredients" VALUES(59,'W-002','P-021',150.0,'г','150 г');
INSERT INTO "recipe_ingredients" VALUES(60,'W-002','P-031',5.0,'г','1 зубчик');
INSERT INTO "recipe_ingredients" VALUES(61,'W-002','P-032',5.0,'г','5 г');
INSERT INTO "recipe_ingredients" VALUES(62,'W-002','P-008',5.0,'г','1 ч.л.');
INSERT INTO "recipe_ingredients" VALUES(63,'W-003','P-011',300.0,'г','300 г');
INSERT INTO "recipe_ingredients" VALUES(64,'W-003','P-002',75.0,'г','3 ст.л.');
INSERT INTO "recipe_ingredients" VALUES(65,'W-003','P-005',60.0,'г','3 ст.л.');
INSERT INTO "recipe_ingredients" VALUES(66,'W-003','P-021',150.0,'г','150 г');
INSERT INTO "recipe_ingredients" VALUES(67,'W-003','P-020',250.0,'г','250 г');
INSERT INTO "recipe_ingredients" VALUES(68,'W-003','P-015',250.0,'г','250 г');
INSERT INTO "recipe_ingredients" VALUES(69,'D-001','P-002',100.0,'г','100 г');
INSERT INTO "recipe_ingredients" VALUES(70,'D-001','P-006',60.0,'г','60 г');
INSERT INTO "recipe_ingredients" VALUES(71,'D-001','P-005',40.0,'г','2 ст.л.');
INSERT INTO "recipe_ingredients" VALUES(72,'D-001','P-025',300.0,'г','300 г');
INSERT INTO "recipe_ingredients" VALUES(73,'D-001','P-026',25.0,'мл','25 мл');
INSERT INTO "recipe_ingredients" VALUES(74,'D-002','P-002',150.0,'г','3 ст.л. ≈150 г');
INSERT INTO "recipe_ingredients" VALUES(75,'D-002','P-004',80.0,'г','4 ст.л.');
INSERT INTO "recipe_ingredients" VALUES(76,'D-002','P-006',60.0,'г','60 г');
INSERT INTO "recipe_ingredients" VALUES(77,'D-002','P-024',150.0,'г','150 г');
INSERT INTO "recipe_ingredients" VALUES(78,'D-002','P-026',25.0,'мл','25 мл');
INSERT INTO "recipe_ingredients" VALUES(79,'G-001','P-018',90.0,'г','≈90 г сухой');
INSERT INTO "recipe_ingredients" VALUES(80,'G-001','P-027',5.0,'мл','1 ч.л.');
INSERT INTO "recipe_ingredients" VALUES(81,'G-001','P-020',300.0,'г','300 г');
INSERT INTO "recipe_ingredients" VALUES(82,'G-001','P-032',10.0,'г','10 г');
INSERT INTO "recipe_ingredients" VALUES(83,'SN-001','P-034',1.0,'шт','1 шт');
INSERT INTO "recipe_ingredients" VALUES(84,'DR-001','P-035',1.0,'бут.','1 бутылка 500 мл');
CREATE TABLE recipes (
  recipe_id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  category TEXT NOT NULL,
  subcategory TEXT,
  version TEXT NOT NULL,
  status TEXT NOT NULL CHECK(status IN ('Draft','Testing','Approved','Archived')),
  servings REAL NOT NULL CHECK(servings > 0),
  tags TEXT
, manual_price_per_serving_rsd REAL);
INSERT INTO "recipes" VALUES('B-001','Яичница с томатами и хлебом','Breakfast','Яичные блюда','1.0','Approved',2.0,'Quick; High protein',NULL);
INSERT INTO "recipes" VALUES('M-001','Куриная запеканка','Main','Высокобелковые','1.0','Approved',3.0,'Meal prep; Low fat',NULL);
INSERT INTO "recipes" VALUES('M-002','Паста болоньезе','Main','Паста','1.1','Approved',2.0,'High protein',NULL);
INSERT INTO "recipes" VALUES('M-003','Домашняя пицца с индейкой','Main','Пицца','1.0','Approved',4.0,'Домашняя',NULL);
INSERT INTO "recipes" VALUES('M-004','Куриные оладьи','Main','Высокобелковые','1.0','Approved',3.0,'Meal prep; Low fat',NULL);
INSERT INTO "recipes" VALUES('M-005','Паста с баклажаном и моцареллой','Main','Паста','1.0','Approved',2.0,'Vegetarian',NULL);
INSERT INTO "recipes" VALUES('S-001','Салат с тунцом','Salad','Высокобелковые','1.0','Approved',2.0,'Low carb',NULL);
INSERT INTO "recipes" VALUES('S-002','Салат с куриным бедром','Salad','Высокобелковые','1.0','Approved',2.0,'Low carb',NULL);
INSERT INTO "recipes" VALUES('S-003','Салат с желудками','Salad','Высокобелковые','1.0','Testing',2.0,'Budget; Low carb',NULL);
INSERT INTO "recipes" VALUES('W-001','Врап с тунцом','Wrap','Протеиновая тортилья','1.0','Approved',2.0,'Quick; High protein',NULL);
INSERT INTO "recipes" VALUES('W-002','Врап с креветками','Wrap','Протеиновая тортилья','1.0','Approved',2.0,'Premium; High protein',NULL);
INSERT INTO "recipes" VALUES('W-003','Врап с куриным бедром','Wrap','Цельнозерновая тортилья','1.0','Approved',2.0,'High protein',NULL);
INSERT INTO "recipes" VALUES('D-001','Крем с ежевикой','Dessert','Белковый крем','1.1','Approved',2.0,'Dessert; Berries',NULL);
INSERT INTO "recipes" VALUES('D-002','Крем с голубикой','Dessert','Белковый крем','1.1','Approved',2.0,'Dessert; Berries',NULL);
INSERT INTO "recipes" VALUES('G-001','Киноа с томатами','Garnish','Крупы','1.0','Approved',2.0,'Vegetarian',NULL);
INSERT INTO "recipes" VALUES('SN-001','Фруктово-протеиновый снек','Snack','Готовый продукт','1.0','Approved',1.0,'Quick',NULL);
INSERT INTO "recipes" VALUES('DR-001','Протеиновый холодный чай','Drink','Готовый продукт','1.0','Approved',1.0,'Quick',NULL);
ANALYZE "sqlite_master";
INSERT INTO "sqlite_stat1" VALUES('workout_logs','idx_workout_logs_date','17 17');
INSERT INTO "sqlite_stat1" VALUES('exercises','sqlite_autoindex_exercises_1','17 1');
INSERT INTO "sqlite_stat1" VALUES('recipe_ingredients','idx_recipe_ingredients_product','84 3');
INSERT INTO "sqlite_stat1" VALUES('recipe_ingredients','idx_recipe_ingredients_recipe','84 5');
INSERT INTO "sqlite_stat1" VALUES('recipe_ingredients','sqlite_autoindex_recipe_ingredients_1','84 5 1 1');
INSERT INTO "sqlite_stat1" VALUES('progress','sqlite_autoindex_progress_1','2 1');
INSERT INTO "sqlite_stat1" VALUES('products','sqlite_autoindex_products_1','35 1');
INSERT INTO "sqlite_stat1" VALUES('recipes','sqlite_autoindex_recipes_1','17 1');
CREATE TABLE workout_logs (
  workout_log_id INTEGER PRIMARY KEY AUTOINCREMENT,
  performed_at TEXT NOT NULL,
  exercise_id TEXT NOT NULL REFERENCES exercises(exercise_id),
  working_weight REAL,
  sets INTEGER,
  reps INTEGER,
  rir TEXT,
  machine_location TEXT,
  comment TEXT
);
INSERT INTO "workout_logs" VALUES(1,'2026-07-14','EX-001',35.0,3,12,'0–2',NULL,NULL);
INSERT INTO "workout_logs" VALUES(2,'2026-07-14','EX-002',20.0,3,12,'0–2',NULL,NULL);
INSERT INTO "workout_logs" VALUES(3,'2026-07-14','EX-003',30.0,3,12,'0–2',NULL,NULL);
INSERT INTO "workout_logs" VALUES(4,'2026-07-14','EX-004',25.0,3,12,'0–2',NULL,NULL);
INSERT INTO "workout_logs" VALUES(5,'2026-07-14','EX-005',10.0,3,12,'0–2',NULL,NULL);
INSERT INTO "workout_logs" VALUES(6,'2026-07-14','EX-006',45.0,3,12,'0–2',NULL,NULL);
INSERT INTO "workout_logs" VALUES(7,'2026-07-14','EX-007',30.0,3,12,'0–2',NULL,'2 × 15 кг');
INSERT INTO "workout_logs" VALUES(8,'2026-07-14','EX-008',25.0,3,12,'0–2',NULL,NULL);
INSERT INTO "workout_logs" VALUES(9,'2026-07-14','EX-009',25.0,3,12,'0–2',NULL,NULL);
INSERT INTO "workout_logs" VALUES(10,'2026-07-14','EX-010',10.0,3,12,'0–2',NULL,'доп. вес');
INSERT INTO "workout_logs" VALUES(11,'2026-07-14','EX-011',5.0,3,12,'0–2',NULL,NULL);
INSERT INTO "workout_logs" VALUES(12,'2026-07-14','EX-012',15.0,3,12,'0–2',NULL,NULL);
INSERT INTO "workout_logs" VALUES(13,'2026-07-14','EX-013',10.0,3,12,'0–2',NULL,NULL);
INSERT INTO "workout_logs" VALUES(14,'2026-07-14','EX-014',10.0,3,12,'0–2',NULL,NULL);
INSERT INTO "workout_logs" VALUES(15,'2026-07-14','EX-015',15.0,3,12,'0–2',NULL,NULL);
INSERT INTO "workout_logs" VALUES(16,'2026-07-14','EX-016',30.0,3,12,'0–2',NULL,NULL);
INSERT INTO "workout_logs" VALUES(17,'2026-07-14','EX-017',15.0,3,12,'0–2',NULL,NULL);
CREATE INDEX idx_recipe_ingredients_recipe ON recipe_ingredients(recipe_id);
CREATE INDEX idx_recipe_ingredients_product ON recipe_ingredients(product_id);
CREATE INDEX idx_food_diary_date ON food_diary(entry_date);
CREATE INDEX idx_workout_logs_date ON workout_logs(performed_at);
CREATE VIEW food_diary_totals AS
SELECT fd.entry_date,
       ROUND(SUM(fd.servings*rps.kcal_per_serving),2) AS kcal,
       ROUND(SUM(fd.servings*rps.protein_per_serving_g),2) AS protein_g,
       ROUND(SUM(fd.servings*rps.fat_per_serving_g),2) AS fat_g,
       ROUND(SUM(fd.servings*rps.carbs_per_serving_g),2) AS carbs_g,
       ROUND(SUM(fd.servings*rps.cost_per_serving_rsd),2) AS cost_rsd
FROM food_diary fd JOIN recipe_per_serving rps ON rps.recipe_id=fd.recipe_id
GROUP BY fd.entry_date;
CREATE VIEW recipe_totals AS
            SELECT r.recipe_id, r.name, r.category, r.subcategory, r.version,
                   r.status, r.servings, r.tags, r.manual_price_per_serving_rsd,
                   ROUND(SUM(CASE WHEN p.unit IN ('шт', 'бут.')
                       THEN ri.quantity * p.price_per_100_or_unit_rsd
                       ELSE ri.quantity * p.price_per_100_or_unit_rsd / 100.0 END), 2)
                       AS recipe_cost_rsd,
                   ROUND(SUM(CASE WHEN p.unit IN ('шт', 'бут.')
                       THEN ri.quantity * p.kcal
                       ELSE ri.quantity * p.kcal / 100.0 END), 2) AS kcal,
                   ROUND(SUM(CASE WHEN p.unit IN ('шт', 'бут.')
                       THEN ri.quantity * p.protein_g
                       ELSE ri.quantity * p.protein_g / 100.0 END), 2) AS protein_g,
                   ROUND(SUM(CASE WHEN p.unit IN ('шт', 'бут.')
                       THEN ri.quantity * p.fat_g
                       ELSE ri.quantity * p.fat_g / 100.0 END), 2) AS fat_g,
                   ROUND(SUM(CASE WHEN p.unit IN ('шт', 'бут.')
                       THEN ri.quantity * p.carbs_g
                       ELSE ri.quantity * p.carbs_g / 100.0 END), 2) AS carbs_g
            FROM recipes r
            LEFT JOIN recipe_ingredients ri ON ri.recipe_id = r.recipe_id
            LEFT JOIN products p ON p.product_id = ri.product_id
            GROUP BY r.recipe_id;
CREATE VIEW recipe_per_serving AS
            SELECT *,
                   ROUND(COALESCE(manual_price_per_serving_rsd,
                       recipe_cost_rsd / servings), 2) AS cost_per_serving_rsd,
                   ROUND(kcal / servings, 2) AS kcal_per_serving,
                   ROUND(protein_g / servings, 2) AS protein_per_serving_g,
                   ROUND(fat_g / servings, 2) AS fat_per_serving_g,
                   ROUND(carbs_g / servings, 2) AS carbs_per_serving_g
            FROM recipe_totals;
DELETE FROM "sqlite_sequence";
INSERT INTO "sqlite_sequence" VALUES('recipe_ingredients',87);
INSERT INTO "sqlite_sequence" VALUES('progress',3);
INSERT INTO "sqlite_sequence" VALUES('workout_logs',18);
INSERT INTO "sqlite_sequence" VALUES('changelog',5);
INSERT INTO "sqlite_sequence" VALUES('food_diary',1);
COMMIT;
