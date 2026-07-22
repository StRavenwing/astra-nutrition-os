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
INSERT INTO "exercises" VALUES('E-002','Ягодицы','Разведение ног в тренажере стоя','кг',3,12,'0–2','');
CREATE TABLE food_diary (
  diary_id INTEGER PRIMARY KEY AUTOINCREMENT,
  entry_date TEXT NOT NULL,
  meal_type TEXT,
  recipe_id TEXT REFERENCES recipes(recipe_id),
  servings REAL NOT NULL DEFAULT 1 CHECK(servings > 0),
  comment TEXT
, product_id TEXT, quantity REAL, measurement_name TEXT, measurement_quantity REAL);
INSERT INTO "food_diary" VALUES(4,'2026-07-14','Обед','M-001',1.0,'',NULL,NULL,NULL,NULL);
INSERT INTO "food_diary" VALUES(5,'2026-07-14','Обед','S-004',1.0,'',NULL,NULL,NULL,NULL);
INSERT INTO "food_diary" VALUES(6,'2026-07-14','Ужин','R-003',1.0,'',NULL,NULL,NULL,NULL);
INSERT INTO "food_diary" VALUES(7,'2026-07-14','Обед','G-002',1.0,'',NULL,NULL,NULL,NULL);
INSERT INTO "food_diary" VALUES(8,'2026-07-15','Обед','G-003',1.0,'',NULL,NULL,NULL,NULL);
INSERT INTO "food_diary" VALUES(9,'2026-07-15','Обед','S-006',1.0,'',NULL,NULL,NULL,NULL);
INSERT INTO "food_diary" VALUES(10,'2026-07-15','Обед','M-001',1.0,'',NULL,NULL,NULL,NULL);
INSERT INTO "food_diary" VALUES(11,'2026-07-15','Перекус','SN-001',1.0,'',NULL,NULL,NULL,NULL);
INSERT INTO "food_diary" VALUES(12,'2026-07-15','Ужин','R-004',1.0,'',NULL,NULL,NULL,NULL);
INSERT INTO "food_diary" VALUES(13,'2026-07-15','Ужин','DR-002',1.0,'',NULL,NULL,NULL,NULL);
INSERT INTO "food_diary" VALUES(14,'2026-07-16','Обед','G-002',0.75,'',NULL,NULL,NULL,NULL);
INSERT INTO "food_diary" VALUES(15,'2026-07-16','Обед','M-008',1.0,'',NULL,NULL,NULL,NULL);
INSERT INTO "food_diary" VALUES(16,'2026-07-16','Обед','S-004',0.75,'',NULL,NULL,NULL,NULL);
INSERT INTO "food_diary" VALUES(17,'2026-07-16','Обед','D-002',1.0,'',NULL,NULL,NULL,NULL);
INSERT INTO "food_diary" VALUES(19,'2026-07-16','Обед',NULL,1.0,'','P-003',100.0,NULL,NULL);
INSERT INTO "food_diary" VALUES(20,'2026-07-16','Ужин','R-001',1.0,'',NULL,NULL,NULL,NULL);
INSERT INTO "food_diary" VALUES(21,'2026-07-16','Перекус',NULL,1.0,'','P-044',200.0,NULL,NULL);
INSERT INTO "food_diary" VALUES(22,'2026-07-17','Обед','G-004',1.0,'',NULL,NULL,NULL,NULL);
INSERT INTO "food_diary" VALUES(23,'2026-07-17','Обед','M-009',1.0,'',NULL,NULL,NULL,NULL);
INSERT INTO "food_diary" VALUES(24,'2026-07-17','Обед','S-007',1.0,'',NULL,NULL,NULL,NULL);
INSERT INTO "food_diary" VALUES(25,'2026-07-17','Напиток','DR-001',1.0,'',NULL,NULL,NULL,NULL);
INSERT INTO "food_diary" VALUES(26,'2026-07-17','Ужин','R-004',1.0,'',NULL,NULL,NULL,NULL);
INSERT INTO "food_diary" VALUES(27,'2026-07-17','Перекус','R-005',1.0,'',NULL,NULL,NULL,NULL);
INSERT INTO "food_diary" VALUES(28,'2026-07-17','Перекус',NULL,1.0,'','P-045',100.0,NULL,NULL);
INSERT INTO "food_diary" VALUES(29,'2026-07-17','Напиток','R-006',1.0,'',NULL,NULL,NULL,NULL);
INSERT INTO "food_diary" VALUES(30,'2026-07-18','Завтрак','B-001',1.0,'',NULL,NULL,NULL,NULL);
INSERT INTO "food_diary" VALUES(31,'2026-07-21','Обед','M-005',1.0,'',NULL,NULL,NULL,NULL);
INSERT INTO "food_diary" VALUES(32,'2026-07-21','Ужин','R-004',1.0,'',NULL,NULL,NULL,NULL);
INSERT INTO "food_diary" VALUES(33,'2026-07-21','Перекус','R-005',1.0,'',NULL,NULL,NULL,NULL);
INSERT INTO "food_diary" VALUES(34,'2026-07-22','Обед','M-001',1.0,'',NULL,NULL,NULL,NULL);
INSERT INTO "food_diary" VALUES(35,'2026-07-22','Обед','S-007',1.0,'',NULL,NULL,NULL,NULL);
INSERT INTO "food_diary" VALUES(36,'2026-07-22','Обед',NULL,1.0,'','P-033',120.0,NULL,NULL);
CREATE TABLE product_measures (
                product_measure_id INTEGER PRIMARY KEY AUTOINCREMENT,
                product_id TEXT NOT NULL REFERENCES products(product_id) ON DELETE CASCADE,
                measure_name TEXT NOT NULL,
                base_quantity REAL NOT NULL CHECK(base_quantity > 0),
                UNIQUE(product_id, measure_name)
            );
INSERT INTO "product_measures" VALUES(1,'P-002','ч. л.',8.0);
INSERT INTO "product_measures" VALUES(2,'P-002','ст. л.',25.0);
INSERT INTO "product_measures" VALUES(3,'P-002','стакан (200 г)',200.0);
INSERT INTO "product_measures" VALUES(4,'P-003','ч. л.',8.0);
INSERT INTO "product_measures" VALUES(5,'P-003','ст. л.',25.0);
INSERT INTO "product_measures" VALUES(6,'P-003','стакан (200 г)',200.0);
INSERT INTO "product_measures" VALUES(7,'P-004','ч. л.',7.0);
INSERT INTO "product_measures" VALUES(8,'P-004','ст. л.',20.0);
INSERT INTO "product_measures" VALUES(9,'P-004','стакан (200 г)',200.0);
INSERT INTO "product_measures" VALUES(10,'P-005','ч. л.',7.0);
INSERT INTO "product_measures" VALUES(11,'P-005','ст. л.',20.0);
INSERT INTO "product_measures" VALUES(12,'P-005','стакан (200 г)',200.0);
INSERT INTO "product_measures" VALUES(13,'P-006','ч. л.',7.0);
INSERT INTO "product_measures" VALUES(14,'P-006','ст. л.',20.0);
INSERT INTO "product_measures" VALUES(15,'P-006','стакан (200 г)',200.0);
INSERT INTO "product_measures" VALUES(16,'P-007','ч. л.',5.0);
INSERT INTO "product_measures" VALUES(17,'P-007','ст. л.',15.0);
INSERT INTO "product_measures" VALUES(18,'P-007','стакан (200 г)',200.0);
INSERT INTO "product_measures" VALUES(19,'P-008','ч. л.',5.0);
INSERT INTO "product_measures" VALUES(20,'P-008','ст. л.',15.0);
INSERT INTO "product_measures" VALUES(21,'P-008','стакан (200 г)',200.0);
INSERT INTO "product_measures" VALUES(22,'P-009','ч. л.',5.0);
INSERT INTO "product_measures" VALUES(23,'P-009','ст. л.',15.0);
INSERT INTO "product_measures" VALUES(24,'P-009','стакан (200 г)',200.0);
INSERT INTO "product_measures" VALUES(25,'P-010','ч. л.',5.0);
INSERT INTO "product_measures" VALUES(26,'P-010','ст. л.',15.0);
INSERT INTO "product_measures" VALUES(27,'P-010','стакан (200 г)',200.0);
INSERT INTO "product_measures" VALUES(28,'P-011','ч. л.',5.0);
INSERT INTO "product_measures" VALUES(29,'P-011','ст. л.',15.0);
INSERT INTO "product_measures" VALUES(30,'P-011','стакан (200 г)',200.0);
INSERT INTO "product_measures" VALUES(31,'P-012','ч. л.',5.0);
INSERT INTO "product_measures" VALUES(32,'P-012','ст. л.',15.0);
INSERT INTO "product_measures" VALUES(33,'P-012','стакан (200 г)',200.0);
INSERT INTO "product_measures" VALUES(34,'P-013','ч. л.',5.0);
INSERT INTO "product_measures" VALUES(35,'P-013','ст. л.',15.0);
INSERT INTO "product_measures" VALUES(36,'P-013','стакан (200 г)',200.0);
INSERT INTO "product_measures" VALUES(37,'P-014','ч. л.',5.0);
INSERT INTO "product_measures" VALUES(38,'P-014','ст. л.',15.0);
INSERT INTO "product_measures" VALUES(39,'P-014','стакан (200 г)',200.0);
INSERT INTO "product_measures" VALUES(40,'P-015','ч. л.',5.0);
INSERT INTO "product_measures" VALUES(41,'P-015','ст. л.',15.0);
INSERT INTO "product_measures" VALUES(42,'P-015','стакан (200 г)',200.0);
INSERT INTO "product_measures" VALUES(43,'P-016','ч. л.',5.0);
INSERT INTO "product_measures" VALUES(44,'P-016','ст. л.',15.0);
INSERT INTO "product_measures" VALUES(45,'P-016','стакан (200 г)',200.0);
INSERT INTO "product_measures" VALUES(46,'P-017','ч. л.',5.0);
INSERT INTO "product_measures" VALUES(47,'P-017','ст. л.',15.0);
INSERT INTO "product_measures" VALUES(48,'P-017','стакан (200 г)',200.0);
INSERT INTO "product_measures" VALUES(49,'P-018','ч. л.',5.0);
INSERT INTO "product_measures" VALUES(50,'P-018','ст. л.',15.0);
INSERT INTO "product_measures" VALUES(51,'P-018','стакан (200 г)',200.0);
INSERT INTO "product_measures" VALUES(52,'P-019','ч. л.',5.0);
INSERT INTO "product_measures" VALUES(53,'P-019','ст. л.',15.0);
INSERT INTO "product_measures" VALUES(54,'P-019','стакан (200 г)',200.0);
INSERT INTO "product_measures" VALUES(55,'P-020','ч. л.',5.0);
INSERT INTO "product_measures" VALUES(56,'P-020','ст. л.',15.0);
INSERT INTO "product_measures" VALUES(57,'P-020','стакан (200 г)',200.0);
INSERT INTO "product_measures" VALUES(58,'P-021','ч. л.',5.0);
INSERT INTO "product_measures" VALUES(59,'P-021','ст. л.',15.0);
INSERT INTO "product_measures" VALUES(60,'P-021','стакан (200 г)',200.0);
INSERT INTO "product_measures" VALUES(61,'P-022','ч. л.',5.0);
INSERT INTO "product_measures" VALUES(62,'P-022','ст. л.',15.0);
INSERT INTO "product_measures" VALUES(63,'P-022','стакан (200 г)',200.0);
INSERT INTO "product_measures" VALUES(64,'P-023','ч. л.',5.0);
INSERT INTO "product_measures" VALUES(65,'P-023','ст. л.',15.0);
INSERT INTO "product_measures" VALUES(66,'P-023','стакан (200 г)',200.0);
INSERT INTO "product_measures" VALUES(67,'P-024','ч. л.',5.0);
INSERT INTO "product_measures" VALUES(68,'P-024','ст. л.',15.0);
INSERT INTO "product_measures" VALUES(69,'P-024','стакан (200 г)',200.0);
INSERT INTO "product_measures" VALUES(70,'P-025','ч. л.',5.0);
INSERT INTO "product_measures" VALUES(71,'P-025','ст. л.',15.0);
INSERT INTO "product_measures" VALUES(72,'P-025','стакан (200 г)',200.0);
INSERT INTO "product_measures" VALUES(73,'P-026','ч. л.',5.0);
INSERT INTO "product_measures" VALUES(74,'P-026','ст. л.',15.0);
INSERT INTO "product_measures" VALUES(75,'P-026','стакан (200 мл)',200.0);
INSERT INTO "product_measures" VALUES(76,'P-027','ч. л.',5.0);
INSERT INTO "product_measures" VALUES(77,'P-027','ст. л.',15.0);
INSERT INTO "product_measures" VALUES(78,'P-027','стакан (200 мл)',200.0);
INSERT INTO "product_measures" VALUES(79,'P-028','ч. л.',5.0);
INSERT INTO "product_measures" VALUES(80,'P-028','ст. л.',15.0);
INSERT INTO "product_measures" VALUES(81,'P-028','стакан (200 мл)',200.0);
INSERT INTO "product_measures" VALUES(82,'P-029','ч. л.',5.0);
INSERT INTO "product_measures" VALUES(83,'P-029','ст. л.',15.0);
INSERT INTO "product_measures" VALUES(84,'P-029','стакан (200 г)',200.0);
INSERT INTO "product_measures" VALUES(85,'P-030','ч. л.',5.0);
INSERT INTO "product_measures" VALUES(86,'P-030','ст. л.',15.0);
INSERT INTO "product_measures" VALUES(87,'P-030','стакан (200 г)',200.0);
INSERT INTO "product_measures" VALUES(88,'P-031','ч. л.',3.0);
INSERT INTO "product_measures" VALUES(89,'P-031','ст. л.',9.0);
INSERT INTO "product_measures" VALUES(90,'P-031','стакан (200 г)',200.0);
INSERT INTO "product_measures" VALUES(91,'P-032','ч. л.',1.0);
INSERT INTO "product_measures" VALUES(92,'P-032','ст. л.',3.0);
INSERT INTO "product_measures" VALUES(93,'P-032','стакан (200 г)',200.0);
INSERT INTO "product_measures" VALUES(94,'P-033','ч. л.',5.0);
INSERT INTO "product_measures" VALUES(95,'P-033','ст. л.',15.0);
INSERT INTO "product_measures" VALUES(96,'P-033','стакан (200 г)',200.0);
INSERT INTO "product_measures" VALUES(97,'P-036','ч. л.',5.0);
INSERT INTO "product_measures" VALUES(98,'P-036','ст. л.',15.0);
INSERT INTO "product_measures" VALUES(99,'P-036','стакан (200 г)',200.0);
INSERT INTO "product_measures" VALUES(100,'P-037','ч. л.',5.0);
INSERT INTO "product_measures" VALUES(101,'P-037','ст. л.',15.0);
INSERT INTO "product_measures" VALUES(102,'P-037','стакан (200 г)',200.0);
INSERT INTO "product_measures" VALUES(103,'P-038','ч. л.',5.0);
INSERT INTO "product_measures" VALUES(104,'P-038','ст. л.',15.0);
INSERT INTO "product_measures" VALUES(105,'P-038','стакан (200 г)',200.0);
INSERT INTO "product_measures" VALUES(106,'P-040','ч. л.',5.0);
INSERT INTO "product_measures" VALUES(107,'P-040','ст. л.',15.0);
INSERT INTO "product_measures" VALUES(108,'P-040','стакан (200 г)',200.0);
INSERT INTO "product_measures" VALUES(109,'P-041','ч. л.',5.0);
INSERT INTO "product_measures" VALUES(110,'P-041','ст. л.',15.0);
INSERT INTO "product_measures" VALUES(111,'P-041','стакан (200 г)',200.0);
INSERT INTO "product_measures" VALUES(112,'P-042','ч. л.',5.0);
INSERT INTO "product_measures" VALUES(113,'P-042','ст. л.',15.0);
INSERT INTO "product_measures" VALUES(114,'P-042','стакан (200 г)',200.0);
INSERT INTO "product_measures" VALUES(115,'P-043','ч. л.',5.0);
INSERT INTO "product_measures" VALUES(116,'P-043','ст. л.',15.0);
INSERT INTO "product_measures" VALUES(117,'P-043','стакан (200 мл)',200.0);
INSERT INTO "product_measures" VALUES(118,'P-044','ч. л.',5.0);
INSERT INTO "product_measures" VALUES(119,'P-044','ст. л.',15.0);
INSERT INTO "product_measures" VALUES(120,'P-044','стакан (200 г)',200.0);
INSERT INTO "product_measures" VALUES(121,'P-045','ч. л.',5.0);
INSERT INTO "product_measures" VALUES(122,'P-045','ст. л.',15.0);
INSERT INTO "product_measures" VALUES(123,'P-045','стакан (200 г)',200.0);
INSERT INTO "product_measures" VALUES(124,'P-046','ч. л.',5.0);
INSERT INTO "product_measures" VALUES(125,'P-046','ст. л.',15.0);
INSERT INTO "product_measures" VALUES(126,'P-046','стакан (200 г)',200.0);
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
INSERT INTO "products" VALUES('P-010','Куриное филе грудки','Мясо','г',350.0,400.0,87.5,110.0,23.0,1.2,0.0,'Оценка','цена не предоставлена');
INSERT INTO "products" VALUES('P-011','Филе куриного бедра','Мясо','г',330.0,780.0,42.31,165.0,19.0,9.0,0.0,'Оценка','КБЖУ средние');
INSERT INTO "products" VALUES('P-012','Куриные желудки','Мясо','г',145.0,450.0,32.22,94.0,18.0,2.0,0.6,'Оценка','КБЖУ средние');
INSERT INTO "products" VALUES('P-013','Креветки королевские в панцире','Морепродукты','г',800.0,400.0,200.0,99.0,24.0,0.3,0.2,'Оценка','в рецепте 400 г покупки ≈200 г мяса');
INSERT INTO "products" VALUES('P-014','Говяжий фарш 7%','Мясо','г',630.0,400.0,157.5,151.0,21.0,7.0,0.0,'Оценка','КБЖУ средние');
INSERT INTO "products" VALUES('P-015','Протеиновая тортилья','Основа','г',180.0,360.0,50.0,279.0,18.0,7.0,37.0,'Подтверждено','КБЖУ на 100 г');
INSERT INTO "products" VALUES('P-016','Паста','Основа','г',140.0,250.0,56.0,311.0,9.8,3.2,52.8,'Подтверждено','КБЖУ на 100 г');
INSERT INTO "products" VALUES('P-017','Рис сухой белый','Крупы','г',241.0,1000.0,24.1,344.0,7.0,0.6,78.0,'Оценка','КБЖУ средние');
INSERT INTO "products" VALUES('P-018','Киноа сухая','Крупы','г',599.0,500.0,119.8,368.0,14.0,6.0,64.0,'Оценка','КБЖУ средние');
INSERT INTO "products" VALUES('P-019','Перловка Aro сухая','Крупы','г',99.8,500.0,19.96,321.0,9.3,1.1,68.4,'Подтверждено','');
INSERT INTO "products" VALUES('P-020','Помидор','Овощи','г',128.0,1000.0,12.8,18.0,0.9,0.2,3.9,'Оценка','КБЖУ средние');
INSERT INTO "products" VALUES('P-021','Огурец','Овощи','г',66.6,450.0,14.8,15.0,0.7,0.1,3.3,'Оценка','КБЖУ средние');
INSERT INTO "products" VALUES('P-022','Баклажан','Овощи','г',248.0,1000.0,24.8,25.0,1.0,0.1,6.0,'Оценка','КБЖУ средние');
INSERT INTO "products" VALUES('P-023','Брокколи','Овощи','г',NULL,NULL,NULL,34.0,2.8,0.4,6.6,'Оценка','цена не предоставлена');
INSERT INTO "products" VALUES('P-024','Голубика','Ягоды','г',450.0,500.0,90.0,57.0,0.7,0.3,14.5,'Оценка','');
INSERT INTO "products" VALUES('P-025','Ежевика','Ягоды','г',300.0,350.0,85.71,43.0,1.4,0.5,9.6,'Оценка','КБЖУ средние');
INSERT INTO "products" VALUES('P-026','Кленовый сироп','Добавки','мл',600.0,350.0,171.43,344.0,0.0,0.0,89.6,'Оценка','на 100 мл, 25 мл ≈86 ккал');
INSERT INTO "products" VALUES('P-027','Оливковое масло','Масла','мл',800.0,1000.0,80.0,884.0,0.0,100.0,0.0,'Оценка','1 ч.л. = 5 мл');
INSERT INTO "products" VALUES('P-028','Растительное масло','Масла','мл',200.0,1000.0,20.0,884.0,0.0,100.0,0.0,'Оценка','цена не предоставлена');
INSERT INTO "products" VALUES('P-029','Соус для пиццы/пасты','Соусы','г',177.0,360.0,49.17,85.5,1.8,7.0,5.3,'Подтверждено','КБЖУ на 100 г');
INSERT INTO "products" VALUES('P-030','Вяленые томаты в масле','Овощи','г',2500.0,1000.0,250.0,260.0,6.0,16.0,23.0,'Оценка','КБЖУ средние');
INSERT INTO "products" VALUES('P-031','Чеснок','Овощи','г',200.0,300.0,66.67,149.0,6.4,0.5,33.1,'Оценка','КБЖУ средние');
INSERT INTO "products" VALUES('P-032','Укроп / петрушка','Зелень','г',70.0,20.0,350.0,36.0,3.0,0.8,6.0,'Оценка','цена одинаковая');
INSERT INTO "products" VALUES('P-033','Бездрожжевой хлеб Lidl','Хлеб','г',136.0,350.0,38.86,230.0,8.0,2.0,44.0,'Оценка','ломтик ≈25 г; КБЖУ оценочные');
INSERT INTO "products" VALUES('P-034','Фруктово-протеиновый снек','Перекусы','шт',170.0,1.0,170.0,199.0,20.0,3.0,23.0,'Подтверждено','на 1 снек');
INSERT INTO "products" VALUES('P-035','Протеиновый холодный чай','Напитки','бут.',199.0,1.0,199.0,80.0,20.0,0.0,0.0,'Подтверждено','500 мл / бутылка');
INSERT INTO "products" VALUES('P-036','Филе лосося (Metro)','Рыба','г',2550.2,1656.0,154.0,208.0,20.4,13.4,0.0,'Подтверждено','');
INSERT INTO "products" VALUES('P-037','Осьминог охлажденный','Морепродукты','г',1553.99,1110.0,140.0,82.0,14.9,1.0,2.2,'Подтверждено','');
INSERT INTO "products" VALUES('P-038','Ежевика замороженная','Ягоды','г',940.0,1500.0,62.67,43.0,1.2,1.0,7.2,'Подтверждено','');
INSERT INTO "products" VALUES('P-040','Булгур','Крупы','г',423.0,1000.0,42.3,339.0,12.3,1.6,68.9,'Подтверждено','');
INSERT INTO "products" VALUES('P-041','Рис интегральный','Крупы','г',215.0,500.0,43.0,348.0,7.1,0.5,72.0,'Подтверждено','');
INSERT INTO "products" VALUES('P-042','Прса из индейки','Мясо','г',390.0,400.0,97.5,102.0,18.0,1.6,4.1,'Подтверждено','');
INSERT INTO "products" VALUES('P-043','Милкшейк Макдональдс','Dessert','мл',350.0,400.0,87.5,117.95,3.21,2.33,20.83,'Подтверждено','');
INSERT INTO "products" VALUES('P-044','Багет Лидл','Хлеб','г',61.5,350.0,17.57,270.0,8.5,1.2,57.0,'Подтверждено','');
INSERT INTO "products" VALUES('P-045','Персик','Ягоды','г',248.0,1000.0,24.8,50.0,0.9,0.1,10.0,'Подтверждено','');
INSERT INTO "products" VALUES('P-046','Перец сладкий','Овощи','г',348.0,1000.0,34.8,27.0,1.7,0.1,5.3,'Подтверждено','');
CREATE TABLE progress (
  progress_id INTEGER PRIMARY KEY AUTOINCREMENT,
  measured_at TEXT NOT NULL UNIQUE,
  weight_kg REAL,
  waist_cm REAL,
  chest_cm REAL,
  hips_cm REAL,
  sleep_score INTEGER CHECK(sleep_score BETWEEN 1 AND 5 OR sleep_score IS NULL),
  wellbeing_score INTEGER CHECK(wellbeing_score BETWEEN 1 AND 5 OR wellbeing_score IS NULL),
  comment TEXT
, height_cm REAL, bmi REAL, body_fat_pct REAL, fat_mass_kg REAL, muscle_pct REAL, muscle_mass_kg REAL, protein_target_g REAL, fat_target_g REAL);
INSERT INTO "progress" VALUES(1,'2025-07-14',78.0,88.0,NULL,NULL,NULL,NULL,'Исторический максимум, приблизительно',169.0,27.31,NULL,NULL,NULL,NULL,NULL,NULL);
INSERT INTO "progress" VALUES(2,'2026-07-14',73.0,81.0,NULL,NULL,NULL,NULL,'Текущая точка',169.0,25.56,NULL,NULL,NULL,NULL,NULL,NULL);
INSERT INTO "progress" VALUES(4,'2026-07-15',74.6,81.0,NULL,103.0,NULL,NULL,'',169.0,26.12,35.9,26.78,60.2,44.91,115.0,70.0);
CREATE TABLE recipe_ingredients (
  recipe_ingredient_id INTEGER PRIMARY KEY AUTOINCREMENT,
  recipe_id TEXT NOT NULL REFERENCES recipes(recipe_id) ON DELETE CASCADE,
  product_id TEXT NOT NULL REFERENCES products(product_id),
  quantity REAL NOT NULL CHECK(quantity >= 0),
  unit TEXT NOT NULL,
  portion_description TEXT, measurement_name TEXT, measurement_quantity REAL,
  UNIQUE(recipe_id, product_id, portion_description)
);
INSERT INTO "recipe_ingredients" VALUES(1,'B-001','P-001',6.0,'шт','6 шт',NULL,NULL);
INSERT INTO "recipe_ingredients" VALUES(2,'B-001','P-020',300.0,'г','300 г',NULL,NULL);
INSERT INTO "recipe_ingredients" VALUES(3,'B-001','P-028',15.0,'мл','1 ст.л.',NULL,NULL);
INSERT INTO "recipe_ingredients" VALUES(4,'B-001','P-032',3.0,'г','3 г',NULL,NULL);
INSERT INTO "recipe_ingredients" VALUES(5,'B-001','P-033',125.0,'г','5 ломтиков ≈125 г',NULL,NULL);
INSERT INTO "recipe_ingredients" VALUES(6,'M-001','P-003',200.0,'г','200 г',NULL,NULL);
INSERT INTO "recipe_ingredients" VALUES(7,'M-001','P-010',400.0,'г','400 г',NULL,NULL);
INSERT INTO "recipe_ingredients" VALUES(8,'M-001','P-004',60.0,'г','3 ст.л. ≈60 г',NULL,NULL);
INSERT INTO "recipe_ingredients" VALUES(9,'M-001','P-001',2.0,'шт','2 шт',NULL,NULL);
INSERT INTO "recipe_ingredients" VALUES(10,'M-001','P-031',7.0,'г','1 зубчик',NULL,NULL);
INSERT INTO "recipe_ingredients" VALUES(11,'M-001','P-032',1.0,'г','1/2 ч.л. сушеного',NULL,NULL);
INSERT INTO "recipe_ingredients" VALUES(12,'M-002','P-014',270.0,'г','270 г',NULL,NULL);
INSERT INTO "recipe_ingredients" VALUES(13,'M-002','P-029',350.0,'г','350 г',NULL,NULL);
INSERT INTO "recipe_ingredients" VALUES(14,'M-002','P-016',250.0,'г','250 г',NULL,NULL);
INSERT INTO "recipe_ingredients" VALUES(15,'M-002','P-008',10.0,'г','2 ч.л.',NULL,NULL);
INSERT INTO "recipe_ingredients" VALUES(20,'M-004','P-010',400.0,'г','400 г',NULL,NULL);
INSERT INTO "recipe_ingredients" VALUES(21,'M-004','P-003',200.0,'г','200 г',NULL,NULL);
INSERT INTO "recipe_ingredients" VALUES(22,'M-004','P-001',1.0,'шт','1 шт',NULL,NULL);
INSERT INTO "recipe_ingredients" VALUES(23,'M-004','P-032',5.0,'г','5 г',NULL,NULL);
INSERT INTO "recipe_ingredients" VALUES(24,'M-004','P-031',5.0,'г','5 г',NULL,NULL);
INSERT INTO "recipe_ingredients" VALUES(25,'M-005','P-022',300.0,'г','300 г',NULL,NULL);
INSERT INTO "recipe_ingredients" VALUES(26,'M-005','P-020',400.0,'г','400 г',NULL,NULL);
INSERT INTO "recipe_ingredients" VALUES(27,'M-005','P-030',20.0,'г','4 половинки',NULL,NULL);
INSERT INTO "recipe_ingredients" VALUES(28,'M-005','P-027',5.0,'мл','1 ч.л.',NULL,NULL);
INSERT INTO "recipe_ingredients" VALUES(29,'M-005','P-007',125.0,'г','125 г',NULL,NULL);
INSERT INTO "recipe_ingredients" VALUES(30,'M-005','P-016',250.0,'г','250 г',NULL,NULL);
INSERT INTO "recipe_ingredients" VALUES(31,'M-005','P-008',5.0,'г','1 ч.л.',NULL,NULL);
INSERT INTO "recipe_ingredients" VALUES(32,'S-001','P-001',2.0,'шт','2 шт',NULL,NULL);
INSERT INTO "recipe_ingredients" VALUES(33,'S-001','P-009',160.0,'г','1 банка',NULL,NULL);
INSERT INTO "recipe_ingredients" VALUES(34,'S-001','P-007',125.0,'г','125 г',NULL,NULL);
INSERT INTO "recipe_ingredients" VALUES(35,'S-001','P-021',150.0,'г','150 г',NULL,NULL);
INSERT INTO "recipe_ingredients" VALUES(36,'S-001','P-029',60.0,'г','соус 60 г',NULL,NULL);
INSERT INTO "recipe_ingredients" VALUES(37,'S-002','P-001',2.0,'шт','2 шт',NULL,NULL);
INSERT INTO "recipe_ingredients" VALUES(38,'S-002','P-011',300.0,'г','300 г сырых',NULL,NULL);
INSERT INTO "recipe_ingredients" VALUES(39,'S-002','P-007',125.0,'г','125 г',NULL,NULL);
INSERT INTO "recipe_ingredients" VALUES(40,'S-002','P-021',150.0,'г','150 г',NULL,NULL);
INSERT INTO "recipe_ingredients" VALUES(41,'S-002','P-029',60.0,'г','соус 60 г',NULL,NULL);
INSERT INTO "recipe_ingredients" VALUES(42,'S-003','P-001',2.0,'шт','2 шт',NULL,NULL);
INSERT INTO "recipe_ingredients" VALUES(43,'S-003','P-012',250.0,'г','250 г',NULL,NULL);
INSERT INTO "recipe_ingredients" VALUES(44,'S-003','P-007',125.0,'г','125 г',NULL,NULL);
INSERT INTO "recipe_ingredients" VALUES(45,'S-003','P-021',150.0,'г','150 г',NULL,NULL);
INSERT INTO "recipe_ingredients" VALUES(46,'S-003','P-029',60.0,'г','соус 60 г',NULL,NULL);
INSERT INTO "recipe_ingredients" VALUES(47,'W-001','P-001',2.0,'шт','2 шт',NULL,NULL);
INSERT INTO "recipe_ingredients" VALUES(48,'W-001','P-021',150.0,'г','150 г',NULL,NULL);
INSERT INTO "recipe_ingredients" VALUES(49,'W-001','P-009',160.0,'г','1 банка',NULL,NULL);
INSERT INTO "recipe_ingredients" VALUES(50,'W-001','P-005',40.0,'г','2 ст.л.',NULL,NULL);
INSERT INTO "recipe_ingredients" VALUES(51,'W-001','P-032',5.0,'г','5 г',NULL,NULL);
INSERT INTO "recipe_ingredients" VALUES(52,'W-001','P-002',100.0,'г','4 ст.л.',NULL,NULL);
INSERT INTO "recipe_ingredients" VALUES(53,'W-001','P-015',160.0,'г','160 г',NULL,NULL);
INSERT INTO "recipe_ingredients" VALUES(54,'W-002','P-015',160.0,'г','160 г',NULL,NULL);
INSERT INTO "recipe_ingredients" VALUES(55,'W-002','P-013',400.0,'г','400 г в панцире; покупка целиком',NULL,NULL);
INSERT INTO "recipe_ingredients" VALUES(56,'W-002','P-002',50.0,'г','2 ст.л.',NULL,NULL);
INSERT INTO "recipe_ingredients" VALUES(57,'W-002','P-005',20.0,'г','1 ст.л.',NULL,NULL);
INSERT INTO "recipe_ingredients" VALUES(58,'W-002','P-020',200.0,'г','200 г',NULL,NULL);
INSERT INTO "recipe_ingredients" VALUES(59,'W-002','P-021',150.0,'г','150 г',NULL,NULL);
INSERT INTO "recipe_ingredients" VALUES(60,'W-002','P-031',5.0,'г','1 зубчик',NULL,NULL);
INSERT INTO "recipe_ingredients" VALUES(61,'W-002','P-032',5.0,'г','5 г',NULL,NULL);
INSERT INTO "recipe_ingredients" VALUES(62,'W-002','P-008',5.0,'г','1 ч.л.',NULL,NULL);
INSERT INTO "recipe_ingredients" VALUES(63,'W-003','P-011',300.0,'г','300 г',NULL,NULL);
INSERT INTO "recipe_ingredients" VALUES(64,'W-003','P-002',75.0,'г','3 ст.л.',NULL,NULL);
INSERT INTO "recipe_ingredients" VALUES(65,'W-003','P-005',60.0,'г','3 ст.л.',NULL,NULL);
INSERT INTO "recipe_ingredients" VALUES(66,'W-003','P-021',150.0,'г','150 г',NULL,NULL);
INSERT INTO "recipe_ingredients" VALUES(67,'W-003','P-020',250.0,'г','250 г',NULL,NULL);
INSERT INTO "recipe_ingredients" VALUES(68,'W-003','P-015',250.0,'г','250 г',NULL,NULL);
INSERT INTO "recipe_ingredients" VALUES(79,'G-001','P-018',90.0,'г','≈90 г сухой',NULL,NULL);
INSERT INTO "recipe_ingredients" VALUES(80,'G-001','P-027',5.0,'мл','1 ч.л.',NULL,NULL);
INSERT INTO "recipe_ingredients" VALUES(81,'G-001','P-020',300.0,'г','300 г',NULL,NULL);
INSERT INTO "recipe_ingredients" VALUES(82,'G-001','P-032',10.0,'г','10 г',NULL,NULL);
INSERT INTO "recipe_ingredients" VALUES(83,'SN-001','P-034',1.0,'шт','1 шт',NULL,NULL);
INSERT INTO "recipe_ingredients" VALUES(88,'D-002','P-002',150.0,'г',NULL,NULL,NULL);
INSERT INTO "recipe_ingredients" VALUES(89,'D-002','P-004',80.0,'г',NULL,NULL,NULL);
INSERT INTO "recipe_ingredients" VALUES(90,'D-002','P-006',60.0,'г',NULL,NULL,NULL);
INSERT INTO "recipe_ingredients" VALUES(91,'D-002','P-024',150.0,'г',NULL,NULL,NULL);
INSERT INTO "recipe_ingredients" VALUES(92,'D-002','P-026',25.0,'мл',NULL,NULL,NULL);
INSERT INTO "recipe_ingredients" VALUES(93,'DR-001','P-035',1.0,'бут.',NULL,NULL,NULL);
INSERT INTO "recipe_ingredients" VALUES(102,'S-004','P-020',250.0,'г',NULL,NULL,NULL);
INSERT INTO "recipe_ingredients" VALUES(103,'S-004','P-027',5.0,'мл',NULL,NULL,NULL);
INSERT INTO "recipe_ingredients" VALUES(104,'S-004','P-032',2.0,'г',NULL,NULL,NULL);
INSERT INTO "recipe_ingredients" VALUES(105,'S-004','P-031',5.0,'г',NULL,NULL,NULL);
INSERT INTO "recipe_ingredients" VALUES(108,'G-002','P-017',60.0,'г',NULL,NULL,NULL);
INSERT INTO "recipe_ingredients" VALUES(110,'G-003','P-040',60.0,'г',NULL,NULL,NULL);
INSERT INTO "recipe_ingredients" VALUES(111,'G-003','P-028',5.0,'мл',NULL,NULL,NULL);
INSERT INTO "recipe_ingredients" VALUES(113,'G-004','P-041',60.0,'г',NULL,NULL,NULL);
INSERT INTO "recipe_ingredients" VALUES(114,'S-005','P-004',40.0,'г',NULL,NULL,NULL);
INSERT INTO "recipe_ingredients" VALUES(115,'S-005','P-032',5.0,'г',NULL,NULL,NULL);
INSERT INTO "recipe_ingredients" VALUES(116,'S-005','P-020',300.0,'г',NULL,NULL,NULL);
INSERT INTO "recipe_ingredients" VALUES(117,'S-005','P-021',150.0,'г',NULL,NULL,NULL);
INSERT INTO "recipe_ingredients" VALUES(118,'M-003','P-015',550.0,'г',NULL,NULL,NULL);
INSERT INTO "recipe_ingredients" VALUES(119,'M-003','P-029',400.0,'г',NULL,NULL,NULL);
INSERT INTO "recipe_ingredients" VALUES(120,'M-003','P-007',125.0,'г',NULL,NULL,NULL);
INSERT INTO "recipe_ingredients" VALUES(121,'M-003','P-042',250.0,'г',NULL,NULL,NULL);
INSERT INTO "recipe_ingredients" VALUES(126,'S-006','P-021',150.0,'г',NULL,NULL,NULL);
INSERT INTO "recipe_ingredients" VALUES(127,'S-006','P-020',300.0,'г',NULL,NULL,NULL);
INSERT INTO "recipe_ingredients" VALUES(128,'S-006','P-032',5.0,'г',NULL,NULL,NULL);
INSERT INTO "recipe_ingredients" VALUES(129,'S-006','P-004',40.0,'г',NULL,NULL,NULL);
INSERT INTO "recipe_ingredients" VALUES(130,'DR-002','P-043',400.0,'мл',NULL,NULL,NULL);
INSERT INTO "recipe_ingredients" VALUES(132,'M-008','P-037',600.0,'г',NULL,NULL,NULL);
INSERT INTO "recipe_ingredients" VALUES(133,'M-008','P-031',10.0,'г',NULL,NULL,NULL);
INSERT INTO "recipe_ingredients" VALUES(134,'M-008','P-032',5.0,'г',NULL,NULL,NULL);
INSERT INTO "recipe_ingredients" VALUES(135,'M-008','P-027',10.0,'мл',NULL,NULL,NULL);
INSERT INTO "recipe_ingredients" VALUES(136,'SN-002','P-004',100.0,'г',NULL,NULL,NULL);
INSERT INTO "recipe_ingredients" VALUES(137,'SN-003','P-003',100.0,'г',NULL,NULL,NULL);
INSERT INTO "recipe_ingredients" VALUES(138,'M-009','P-036',400.0,'г',NULL,NULL,NULL);
INSERT INTO "recipe_ingredients" VALUES(139,'M-009','P-027',5.0,'мл',NULL,NULL,NULL);
INSERT INTO "recipe_ingredients" VALUES(140,'M-009','P-032',5.0,'г',NULL,NULL,NULL);
INSERT INTO "recipe_ingredients" VALUES(146,'S-007','P-021',80.0,'г',NULL,NULL,NULL);
INSERT INTO "recipe_ingredients" VALUES(147,'S-007','P-046',120.0,'г',NULL,NULL,NULL);
INSERT INTO "recipe_ingredients" VALUES(148,'S-007','P-020',170.0,'г',NULL,NULL,NULL);
INSERT INTO "recipe_ingredients" VALUES(149,'S-007','P-027',5.0,'мл',NULL,NULL,NULL);
INSERT INTO "recipe_ingredients" VALUES(150,'S-007','P-032',5.0,'г',NULL,NULL,NULL);
INSERT INTO "recipe_ingredients" VALUES(151,'D-001','P-002',100.0,'г',NULL,NULL,NULL);
INSERT INTO "recipe_ingredients" VALUES(152,'D-001','P-006',60.0,'г',NULL,NULL,NULL);
INSERT INTO "recipe_ingredients" VALUES(153,'D-001','P-005',40.0,'г',NULL,NULL,NULL);
INSERT INTO "recipe_ingredients" VALUES(154,'D-001','P-025',300.0,'г',NULL,NULL,NULL);
INSERT INTO "recipe_ingredients" VALUES(155,'D-001','P-026',25.0,'мл',NULL,NULL,NULL);
INSERT INTO "recipe_ingredients" VALUES(156,'D-003','P-002',150.0,'г',NULL,NULL,NULL);
INSERT INTO "recipe_ingredients" VALUES(157,'D-003','P-004',80.0,'г',NULL,NULL,NULL);
INSERT INTO "recipe_ingredients" VALUES(158,'D-003','P-006',60.0,'г',NULL,NULL,NULL);
INSERT INTO "recipe_ingredients" VALUES(159,'D-003','P-026',25.0,'мл',NULL,NULL,NULL);
INSERT INTO "recipe_ingredients" VALUES(160,'D-003','P-045',250.0,'г',NULL,NULL,NULL);
CREATE TABLE recipes (
  recipe_id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  category TEXT NOT NULL,
  subcategory TEXT,
  version TEXT NOT NULL,
  status TEXT NOT NULL CHECK(status IN ('Draft','Testing','Approved','Archived')),
  servings REAL NOT NULL CHECK(servings > 0),
  tags TEXT
, manual_price_per_serving_rsd REAL, manual_kcal_per_serving REAL, manual_protein_per_serving_g REAL, manual_fat_per_serving_g REAL, manual_carbs_per_serving_g REAL);
INSERT INTO "recipes" VALUES('B-001','Яичница с томатами и хлебом','Breakfast','Яичные блюда','1.0','Approved',2.0,'Quick; High protein',NULL,NULL,NULL,NULL,NULL);
INSERT INTO "recipes" VALUES('M-001','Куриная запеканка','Main','Высокобелковые','1.0','Approved',3.0,'Meal prep; Low fat',NULL,NULL,NULL,NULL,NULL);
INSERT INTO "recipes" VALUES('M-002','Паста болоньезе','Main','Паста','1.1','Approved',2.0,'High protein',NULL,NULL,NULL,NULL,NULL);
INSERT INTO "recipes" VALUES('M-003','Домашняя пицца с индейкой','Main','Пицца','1.0','Approved',4.0,'Домашняя',NULL,NULL,NULL,NULL,NULL);
INSERT INTO "recipes" VALUES('M-004','Куриные оладьи','Main','Высокобелковые','1.0','Approved',3.0,'Meal prep; Low fat',NULL,NULL,NULL,NULL,NULL);
INSERT INTO "recipes" VALUES('M-005','Паста с баклажаном и моцареллой','Main','Паста','1.0','Approved',2.0,'Vegetarian',NULL,NULL,NULL,NULL,NULL);
INSERT INTO "recipes" VALUES('S-001','Салат с тунцом','Salad','Высокобелковые','1.0','Approved',2.0,'Low carb',NULL,NULL,NULL,NULL,NULL);
INSERT INTO "recipes" VALUES('S-002','Салат с куриным бедром','Salad','Высокобелковые','1.0','Approved',2.0,'Low carb',NULL,NULL,NULL,NULL,NULL);
INSERT INTO "recipes" VALUES('S-003','Салат с желудками','Salad','Высокобелковые','1.0','Testing',2.0,'Budget; Low carb',NULL,NULL,NULL,NULL,NULL);
INSERT INTO "recipes" VALUES('W-001','Врап с тунцом','Wrap','Протеиновая тортилья','1.0','Approved',2.0,'Quick; High protein',NULL,NULL,NULL,NULL,NULL);
INSERT INTO "recipes" VALUES('W-002','Врап с креветками','Wrap','Протеиновая тортилья','1.0','Approved',2.0,'Premium; High protein',NULL,NULL,NULL,NULL,NULL);
INSERT INTO "recipes" VALUES('W-003','Врап с куриным бедром','Wrap','Цельнозерновая тортилья','1.0','Approved',2.0,'High protein',NULL,NULL,NULL,NULL,NULL);
INSERT INTO "recipes" VALUES('D-001','Крем с ежевикой','Dessert','Белковый крем','1.1','Approved',2.0,'Dessert; Berries',NULL,NULL,NULL,NULL,NULL);
INSERT INTO "recipes" VALUES('D-002','Крем с голубикой','Dessert','Белковый крем','1.1','Approved',2.0,'Dessert; Berries',NULL,NULL,NULL,NULL,NULL);
INSERT INTO "recipes" VALUES('G-001','Киноа с томатами','Garnish','Крупы','1.0','Approved',2.0,'Vegetarian',NULL,NULL,NULL,NULL,NULL);
INSERT INTO "recipes" VALUES('SN-001','Фруктово-протеиновый снек','Snack','Готовый продукт','1.0','Approved',1.0,'Quick',NULL,NULL,NULL,NULL,NULL);
INSERT INTO "recipes" VALUES('DR-001','Протеиновый холодный чай','Drink','Готовый продукт','1.0','Approved',1.0,'Quick',199.0,NULL,NULL,NULL,NULL);
INSERT INTO "recipes" VALUES('S-004','Салат из томатов с чесноком','Salad','','1.0','Draft',2.0,'',NULL,NULL,NULL,NULL,NULL);
INSERT INTO "recipes" VALUES('G-002','Рис отварной','Garnish','','1.0','Draft',2.0,'',NULL,NULL,NULL,NULL,NULL);
INSERT INTO "recipes" VALUES('G-003','Булгур отварной','Garnish','','1.0','Draft',2.0,'',NULL,NULL,NULL,NULL,NULL);
INSERT INTO "recipes" VALUES('G-004','Рис интегральный отварной','Garnish','','1.0','Draft',2.0,'',NULL,NULL,NULL,NULL,NULL);
INSERT INTO "recipes" VALUES('S-005','Салат из томатов и огурцов с йогуртом','Salad','','1.0','Draft',2.0,'',NULL,NULL,NULL,NULL,NULL);
INSERT INTO "recipes" VALUES('S-006','Салат из томатов и огурцов со скиром','Salad','','1.0','Draft',2.0,'',NULL,NULL,NULL,NULL,NULL);
INSERT INTO "recipes" VALUES('DR-002','Милкшейк Макдональдс большой','Drink','','1.0','Draft',1.0,'',NULL,NULL,NULL,NULL,NULL);
INSERT INTO "recipes" VALUES('M-008','Осьминог с чесноком','Main','','1.0','Draft',3.0,'',NULL,NULL,NULL,NULL,NULL);
INSERT INTO "recipes" VALUES('SN-002','Скир 100г','Snack','','1.0','Draft',1.0,'',NULL,NULL,NULL,NULL,NULL);
INSERT INTO "recipes" VALUES('SN-003','Творог 0,2% 100г','Snack','','1.0','Draft',1.0,'',NULL,NULL,NULL,NULL,NULL);
INSERT INTO "recipes" VALUES('M-009','Лосось запеченный с лемонграссом','Main','','1.0','Draft',2.0,'',NULL,NULL,NULL,NULL,NULL);
INSERT INTO "recipes" VALUES('R-001','Жареные пельмени с говядиной Super Snack Bar','Ready','Готовый продукт','1.0','Draft',1.0,'',930.0,750.0,27.0,40.0,70.0);
INSERT INTO "recipes" VALUES('R-002','Тофу Super Snack Bar','Ready','Готовый продукт','1.0','Draft',1.0,'',690.0,745.0,32.0,23.5,97.0);
INSERT INTO "recipes" VALUES('R-003','Шаурма М','Ready','Готовый продукт','1.0','Draft',1.0,'',785.0,720.0,42.0,28.0,72.0);
INSERT INTO "recipes" VALUES('R-004','Телячьи ленты Walter','Ready','Готовый продукт','1.0','Draft',1.0,'',1350.0,285.0,52.5,7.5,0.0);
INSERT INTO "recipes" VALUES('S-007','Салат из томатов с перцем и огурцом','Salad','','1.0','Draft',2.0,'',NULL,NULL,NULL,NULL,NULL);
INSERT INTO "recipes" VALUES('R-005','Протеиновый сырок','Ready','Готовый продукт','1.0','Draft',1.0,'',79.0,134.8,8.0,7.6,8.4);
INSERT INTO "recipes" VALUES('R-006','Пиво Birra Moretti','Ready','Готовый продукт','1.0','Draft',1.0,'',99.0,200.0,0.0,0.0,14.0);
INSERT INTO "recipes" VALUES('D-003','Крем с персиком','Dessert','Белковый крем','1.0','Draft',2.0,'',NULL,NULL,NULL,NULL,NULL);
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
INSERT INTO "workout_logs" VALUES(7,'2026-07-14','EX-007',40.0,3,12,'0–2','','2 × 15 кг');
INSERT INTO "workout_logs" VALUES(8,'2026-07-14','EX-008',25.0,3,12,'0–2',NULL,NULL);
INSERT INTO "workout_logs" VALUES(9,'2026-07-14','EX-009',25.0,3,12,'0–2',NULL,NULL);
INSERT INTO "workout_logs" VALUES(10,'2026-07-14','EX-010',12.5,3,12,'0–2','','доп. вес');
INSERT INTO "workout_logs" VALUES(11,'2026-07-14','EX-011',5.0,3,12,'0–2',NULL,NULL);
INSERT INTO "workout_logs" VALUES(12,'2026-07-14','EX-012',15.0,3,12,'0–2',NULL,NULL);
INSERT INTO "workout_logs" VALUES(13,'2026-07-14','EX-013',10.0,3,12,'0–2',NULL,NULL);
INSERT INTO "workout_logs" VALUES(14,'2026-07-14','EX-014',10.0,3,12,'0–2',NULL,NULL);
INSERT INTO "workout_logs" VALUES(15,'2026-07-14','EX-015',15.0,3,12,'0–2',NULL,NULL);
INSERT INTO "workout_logs" VALUES(16,'2026-07-14','EX-016',30.0,3,12,'0–2',NULL,NULL);
INSERT INTO "workout_logs" VALUES(17,'2026-07-14','EX-017',15.0,3,12,'0–2',NULL,NULL);
INSERT INTO "workout_logs" VALUES(19,'2026-07-15','E-002',50.0,3,12,'0–2','','');
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
                   r.manual_kcal_per_serving, r.manual_protein_per_serving_g,
                   r.manual_fat_per_serving_g, r.manual_carbs_per_serving_g,
                   ROUND(SUM(CASE WHEN p.unit IN ('шт', 'бут.')
                       THEN ri.quantity * p.price_per_100_or_unit_rsd
                       ELSE ri.quantity * p.price_per_100_or_unit_rsd / 100.0 END), 2)
                       AS recipe_cost_rsd,
                   ROUND(COALESCE(r.manual_kcal_per_serving * r.servings,
                       SUM(CASE WHEN p.unit IN ('шт', 'бут.')
                       THEN ri.quantity * p.kcal
                       ELSE ri.quantity * p.kcal / 100.0 END)), 2) AS kcal,
                   ROUND(COALESCE(r.manual_protein_per_serving_g * r.servings,
                       SUM(CASE WHEN p.unit IN ('шт', 'бут.')
                       THEN ri.quantity * p.protein_g
                       ELSE ri.quantity * p.protein_g / 100.0 END)), 2) AS protein_g,
                   ROUND(COALESCE(r.manual_fat_per_serving_g * r.servings,
                       SUM(CASE WHEN p.unit IN ('шт', 'бут.')
                       THEN ri.quantity * p.fat_g
                       ELSE ri.quantity * p.fat_g / 100.0 END)), 2) AS fat_g,
                   ROUND(COALESCE(r.manual_carbs_per_serving_g * r.servings,
                       SUM(CASE WHEN p.unit IN ('шт', 'бут.')
                       THEN ri.quantity * p.carbs_g
                       ELSE ri.quantity * p.carbs_g / 100.0 END)), 2) AS carbs_g
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
INSERT INTO "sqlite_sequence" VALUES('recipe_ingredients',160);
INSERT INTO "sqlite_sequence" VALUES('progress',4);
INSERT INTO "sqlite_sequence" VALUES('workout_logs',19);
INSERT INTO "sqlite_sequence" VALUES('changelog',5);
INSERT INTO "sqlite_sequence" VALUES('food_diary',36);
INSERT INTO "sqlite_sequence" VALUES('product_measures',420);
COMMIT;
