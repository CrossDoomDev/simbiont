class_name EvolutionData
extends RefCounted
## Editable dependency graphs. Every edge is an AND prerequisite with a rank.
const HOST_BRANCHES := {
	"assault": {"name": "Хищное оружие", "color": Color("e38ba9")},
	"vitality": {"name": "Живая плоть", "color": Color("b4d28a")},
	"motion": {"name": "Нервный импульс", "color": Color("78d9da")},
	"hunt": {"name": "Чувства охотника", "color": Color("d3b572")},
	"synapse": {"name": "Резонанс связи", "color": Color("bb94e5")},
	"carapace": {"name": "Хитиновый обет", "color": Color("f0a976")},
}

static func host_nodes(legacy: Dictionary) -> Dictionary:
	var result := legacy.duplicate(true)
	result["resonator"].merge({"branch":"assault","position":Vector2(40,210),"requires":{},"effects":{}})
	result["regeneration"].merge({"branch":"vitality","position":Vector2(40,650),"requires":{},"effects":{}})
	result["muscle"].merge({"branch":"motion","position":Vector2(55,980),"requires":{},"effects":{}})
	result["receptor"].merge({"branch":"hunt","position":Vector2(40,1200),"requires":{},"effects":{}})
	var rows: Array[Dictionary] = [
		{"id":"serration", "name":"Зубчатые каналы", "description":"Базовый урон оружия и способностей +6% за ранг.", "branch":"assault", "max_level":3, "requires":{"resonator":1}, "effects":{"damage_bonus":0.06}, "tier":1,"position":Vector2(270,80),"color":Color("e38ba9")},
		{"id":"cadence", "name":"Сдвоенный пульс", "description":"Частота огня +4% за ранг.", "branch":"assault", "max_level":3, "requires":{"serration":1}, "effects":{"fire_bonus":0.04}, "tier":2,"position":Vector2(480,45),"color":Color("e38ba9")},
		{"id":"velocity", "name":"Разгонный проток", "description":"Скорость снарядов +6% за ранг.", "branch":"assault", "max_level":3, "requires":{"serration":2}, "effects":{"projectile_bonus":0.06}, "tier":3,"position":Vector2(500,155),"color":Color("e38ba9")},
		{"id":"perforation", "name":"Сквозной шип", "description":"Пробивает ещё одну цель за ранг. Стены останавливают шип.", "branch":"assault", "max_level":2, "requires":{"velocity":1}, "effects":{"pierce":1}, "tier":4,"position":Vector2(725,65),"color":Color("e38ba9")},
		{"id":"execution", "name":"Последний укус", "description":"Урон целям ниже 35% здоровья +8% за ранг.", "branch":"assault", "max_level":3, "requires":{"cadence":2, "velocity":1}, "effects":{"execute_bonus":0.08}, "tier":5,"position":Vector2(755,185),"color":Color("e38ba9")},
		{"id":"apex_barrage", "name":"Венец: тройная пасть", "description":"Оружие выпускает три шипа веером, каждый наносит 65% урона. Все свойства шипов сохраняются.", "branch":"assault", "max_level":1, "requires":{"perforation":2, "execution":3, "resonator":3}, "effects":{"multishot":1}, "tier":6,"position":Vector2(1000,105),"color":Color("e38ba9")},
		{"id":"marrow", "name":"Кровяные полости", "description":"Максимальное здоровье +8 за ранг.", "branch":"vitality", "max_level":5, "requires":{"regeneration":1}, "effects":{"hp_flat":8}, "tier":1,"position":Vector2(280,740),"color":Color("b4d28a")},
		{"id":"dermis", "name":"Слоистая дерма", "description":"Снижение любого входящего урона +2% за ранг.", "branch":"vitality", "max_level":5, "requires":{"regeneration":1}, "effects":{"armor":0.02}, "tier":2,"position":Vector2(290,845),"color":Color("b4d28a")},
		{"id":"renewal", "name":"Тихая регенерация", "description":"Восстановление вне урона +0,04 HP/с за ранг.", "branch":"vitality", "max_level":5, "requires":{"marrow":2}, "effects":{"regen_flat":0.04}, "tier":3,"position":Vector2(520,715),"color":Color("b4d28a")},
		{"id":"recovery", "name":"Быстрый рубец", "description":"Задержка регенерации после удара меньше на 0,3 с за ранг.", "branch":"vitality", "max_level":3, "requires":{"renewal":2}, "effects":{"regen_delay_reduction":0.3}, "tier":4,"position":Vector2(735,725),"color":Color("b4d28a")},
		{"id":"leech", "name":"Кровный обмен", "description":"Обычные шипы возвращают 0,5% фактического урона здоровьем за ранг. Избыточный урон не учитывается.", "branch":"vitality", "max_level":3, "requires":{"dermis":2,"serration":1}, "effects":{"lifesteal":0.005}, "tier":5,"position":Vector2(715,840),"color":Color("b4d28a")},
		{"id":"undying", "name":"Венец: второе сердце", "description":"Один раз за вылазку переживает смертельный удар:25% HP и 2 с неуязвимости.", "branch":"vitality", "max_level":1, "requires":{"marrow":5,"recovery":3,"leech":2,"regeneration":3}, "effects":{"revive":1}, "tier":6,"position":Vector2(1000,785),"color":Color("b4d28a")},
		{"id":"stride", "name":"Эластичные сухожилия", "description":"Скорость передвижения +3% за ранг.", "branch":"motion", "max_level":3, "requires":{"muscle":1}, "effects":{"speed_bonus":0.03}, "tier":1,"position":Vector2(300,960),"color":Color("78d9da")},
		{"id":"dash_length", "name":"Сжатая пружина", "description":"Длина рывка +8% за ранг.", "branch":"motion", "max_level":3, "requires":{"stride":1}, "effects":{"dash_length":0.08}, "tier":2,"position":Vector2(530,945),"color":Color("78d9da")},
		{"id":"dash_cooldown", "name":"Возвратный рефлекс", "description":"Перезарядка рывка меньше на 5% за ранг.", "branch":"motion", "max_level":3, "requires":{"dash_length":2}, "effects":{"dash_cooldown":0.05}, "tier":3,"position":Vector2(745,925),"color":Color("78d9da")},
		{"id":"slip", "name":"Текучее тело", "description":"Неуязвимость после обычного попадания дольше на 0,04 с за ранг.", "branch":"motion", "max_level":3, "requires":{"stride":2}, "effects":{"hurt_grace":0.04}, "tier":4,"position":Vector2(500,1055),"color":Color("78d9da")},
		{"id":"kinetic", "name":"Кинетический голод", "description":"Урон обычного оружия в движении +5% за ранг.", "branch":"motion", "max_level":3, "requires":{"stride":3,"cadence":1}, "effects":{"moving_damage":0.05}, "tier":5,"position":Vector2(760,1050),"color":Color("78d9da")},
		{"id":"apex_dash", "name":"Венец: бритвенный след", "description":"Рывок наносит вдвое больше урона и захватывает полосу в полтора раза шире.", "branch":"motion", "max_level":1, "requires":{"dash_length":3,"dash_cooldown":3,"kinetic":2,"muscle":3}, "effects":{"dash_apex":1}, "tier":6,"position":Vector2(1020,1005),"color":Color("78d9da")},
		{"id":"magnet", "name":"Ловчие реснички", "description":"Радиус притяжения добычи +10% за ранг.", "branch":"hunt", "max_level":3, "requires":{"receptor":1}, "effects":{"pickup_bonus":0.1}, "tier":1,"position":Vector2(265,1180),"color":Color("d3b572")},
		{"id":"optic", "name":"Глубокий взгляд", "description":"Дальность автообнаружения +5% за ранг.", "branch":"hunt", "max_level":3, "requires":{"receptor":2}, "effects":{"detection_bonus":0.05}, "tier":2,"position":Vector2(280,1310),"color":Color("d3b572")},
		{"id":"precision", "name":"Узкий зрачок", "description":"Шанс критического попадания +2% за ранг. Базовый крит наносит 150% урона.", "branch":"hunt", "max_level":5, "requires":{"optic":1,"resonator":1}, "effects":{"crit_chance":0.02}, "tier":3,"position":Vector2(510,1210),"color":Color("d3b572")},
		{"id":"crit_power", "name":"Обнажённый нерв", "description":"Множитель критического попадания +0,15 за ранг.", "branch":"hunt", "max_level":3, "requires":{"precision":2}, "effects":{"crit_power":0.15}, "tier":4,"position":Vector2(755,1170),"color":Color("d3b572")},
		{"id":"giant_hunter", "name":"Запах стража", "description":"Урон обычных шипов стражам +6% за ранг.", "branch":"hunt", "max_level":3, "requires":{"optic":2,"serration":1}, "effects":{"boss_damage":0.06}, "tier":5,"position":Vector2(745,1325),"color":Color("d3b572")},
		{"id":"apex_hunter", "name":"Венец: идеальный хищник", "description":"Ещё +10% шанса крита и +1 пробитая цель для каждого шипа.", "branch":"hunt", "max_level":1, "requires":{"crit_power":3,"precision":5,"giant_hunter":2,"receptor":3}, "effects":{"crit_chance":0.1, "pierce":1}, "tier":6,"position":Vector2(1020,1260),"color":Color("d3b572")},
		{"id":"neuron", "name":"Нейронные гроздья", "description":"Урон всех активных способностей +4% за ранг.", "branch":"synapse", "max_level":5, "requires":{"resonator":2}, "effects":{"skill_power":0.04}, "tier":1,"position":Vector2(292,300),"color":Color("bb94e5")},
		{"id":"echo", "name":"Обратное эхо", "description":"Перезарядка всех способностей меньше на 3% за ранг.", "branch":"synapse", "max_level":5, "requires":{"neuron":1}, "effects":{"skill_cooldown":0.03}, "tier":2,"position":Vector2(520,260),"color":Color("bb94e5")},
		{"id":"catalyst", "name":"Экономный катализ", "description":"Стоимость способностей меньше на 2% за ранг. Скорость накопления энергии не растёт.", "branch":"synapse", "max_level":5, "requires":{"receptor":2}, "effects":{"skill_cost":0.02}, "tier":3,"position":Vector2(290,405),"color":Color("bb94e5")},
		{"id":"spore_time", "name":"Живучие споры", "description":"Ядовитое облако существует на 0,5 с дольше за ранг.", "branch":"synapse", "max_level":3, "requires":{"neuron":2}, "effects":{"spore_duration":0.5}, "tier":4,"position":Vector2(745,300),"color":Color("bb94e5")},
		{"id":"wave_area", "name":"Расходящаяся волна", "description":"Радиус нейроволны +6% за ранг.", "branch":"synapse", "max_level":3, "requires":{"echo":2,"shield_flesh":1}, "effects":{"wave_radius":0.06}, "tier":5,"position":Vector2(730,410),"color":Color("bb94e5")},
		{"id":"apex_nova", "name":"Венец: разомкнутая связь", "description":"Радиус ПКМ +25%, стоимость ПКМ меньше ещё на 20%.", "branch":"synapse", "max_level":1, "requires":{"catalyst":5,"wave_area":3,"spore_time":2,"resonator":3}, "effects":{"nova_apex":1}, "tier":6,"position":Vector2(1020,350),"color":Color("bb94e5")},
		{"id":"shield_flesh", "name":"Плотный кокон", "description":"Прочность хитинового кокона +8% за ранг.", "branch":"carapace", "max_level":3, "requires":{"regeneration":2}, "effects":{"shield_power":0.08}, "tier":1,"position":Vector2(262,520),"color":Color("f0a976")},
		{"id":"shield_time", "name":"Долгая оболочка", "description":"Время кокона +0,4 с за ранг.", "branch":"carapace", "max_level":3, "requires":{"shield_flesh":1}, "effects":{"shield_duration":0.4}, "tier":2,"position":Vector2(500,520),"color":Color("f0a976")},
		{"id":"ward", "name":"Гасительные чешуи", "description":"Урон вражеских снарядов меньше на 3% за ранг, дополнительно к броне.", "branch":"carapace", "max_level":3, "requires":{"dermis":2}, "effects":{"projectile_ward":0.03}, "tier":3,"position":Vector2(520,625),"color":Color("f0a976")},
		{"id":"cast_heal", "name":"Успокаивающий пульс", "description":"Успешное применение способности восстанавливает 1 HP за ранг.", "branch":"carapace", "max_level":3, "requires":{"shield_flesh":2,"neuron":1}, "effects":{"cast_heal":1}, "tier":4,"position":Vector2(755,500),"color":Color("f0a976")},
		{"id":"spore_potency", "name":"Едкая железа", "description":"Урон ядовитых спор дополнительно +8% за ранг.", "branch":"carapace", "max_level":3, "requires":{"spore_time":1,"shield_time":2}, "effects":{"spore_power":0.08}, "tier":5,"position":Vector2(740,625),"color":Color("f0a976")},
		{"id":"apex_guard", "name":"Венец: осколочная линька", "description":"Когда кокон полностью разбит, осколки бьют по ближайшим врагам на 3× урона. Не даёт энергии.", "branch":"carapace", "max_level":1, "requires":{"shield_time":3,"ward":3,"cast_heal":3,"regeneration":3}, "effects":{"shield_burst":1}, "tier":6,"position":Vector2(1000,565),"color":Color("f0a976")},
	]
	for node: Dictionary in rows:
		node["costs"] = _costs(int(node["tier"]),int(node["max_level"]))
		result[node["id"]] = node
	return result

static func _costs(tier: int, ranks: int) -> Array:
	var result: Array = []
	for rank: int in ranks:
		var factor := 1.0 + rank*0.55
		result.append([int((12+tier*7)*factor),int((2+tier*2)*factor),int((1+tier)*factor),2 if tier == 6 else (1 if tier >= 4 and rank > 0 else 0)])
	return result

static func ship_nodes() -> Dictionary:
	var rows: Array[Dictionary] = [
		{"id":"heart", "name":"Энергетическое сердце", "description":"Восстанавливает пульс корабля. Стадия II открывает Багровую низину; глубокие ветви требуют следующих стадий.", "max_level":4, "requires":{}, "branch":"heart","position":Vector2(40,210),"color":Color("e49b77")},
		{"id":"navigation", "name":"Нейронное ядро", "description":"Восстановление памяти маршрутов; открывает ветви архива и разведки.", "max_level":4, "requires":{}, "branch":"memory","position":Vector2(55,50),"color":Color("7acfdc")},
		{"id":"regeneration", "name":"Зародышевый узел", "description":"Восстанавливает ткани закрытых отсеков и доступ к карантинным протоколам.", "max_level":4, "requires":{}, "branch":"rooms","position":Vector2(40,640),"color":Color("ba95dc")},
		{"id":"storage", "name":"Питающая камера", "description":"Восстанавливает сосуды хранения и доступ к переработке и страховке добычи.", "max_level":4, "requires":{}, "branch":"economy","position":Vector2(50,980),"color":Color("9ece86")},
		{"id":"archive_door", "name":"Вскрытие архива", "description":"Открывает настоящий отсек Архива на востоке корабля. Внутри — журнал вылазок и разведданные.", "max_level":1, "requires":{"navigation":1,"heart":1}, "branch":"memory","position":Vector2(280,60),"color":Color("7acfdc")},
		{"id":"cave_echo", "name":"Слух пустот", "description":"Входы пещер становятся видны на боевой миникарте.", "max_level":1, "requires":{"archive_door":1}, "branch":"memory","position":Vector2(510,20),"color":Color("7acfdc")},
		{"id":"threat_echo", "name":"Эхо движения", "description":"Показывает живых врагов на боевой миникарте в пределах 400 пикселей от носителя.", "max_level":1, "requires":{"archive_door":1}, "branch":"memory","position":Vector2(510,155),"color":Color("7acfdc")},
		{"id":"survey", "name":"Память горизонта", "description":"Расширяет корабельную разведку:эхо врагов показывает всю комнату.", "max_level":1, "requires":{"threat_echo":1, "navigation":3}, "branch":"memory","position":Vector2(760,140),"color":Color("7acfdc")},
		{"id":"blackbox", "name":"Чёрная память", "description":"Архив хранит 50 последних вылазок вместо 20.", "max_level":1, "requires":{"archive_door":1, "navigation":2}, "branch":"memory","position":Vector2(760,20),"color":Color("7acfdc")},
		{"id":"refinery_door", "name":"Пищеварительный отсек", "description":"Открывает новую камеру переработки на юго-востоке корабля.", "max_level":1, "requires":{"storage":1,"heart":1}, "branch":"economy","position":Vector2(290,845),"color":Color("9ece86")},
		{"id":"converter", "name":"Ферментная перегонка", "description":"В переработчике доступны рецепты биомасса → ткань и биомасса → фермент.", "max_level":1, "requires":{"refinery_door":1}, "branch":"economy","position":Vector2(510,805),"color":Color("9ece86")},
		{"id":"efficient_conversion", "name":"Бережный катализ", "description":"Каждый ранг уменьшает расход биомассы в базовых рецептах на 2:12 → 10 → 8 → 6.", "max_level":3, "requires":{"converter":1}, "branch":"economy","position":Vector2(750,760),"color":Color("9ece86")},
		{"id":"core_synthesis", "name":"Сборка ядра", "description":"Открывает рецепт: 80 биомассы + 30 ткани + 20 фермента → 1 ядро.", "max_level":1, "requires":{"converter":1, "heart":2}, "branch":"economy","position":Vector2(980,840),"color":Color("9ece86")},
		{"id":"salvage", "name":"Аварийные мешки", "description":"После поражения сохраняется ещё 5% собранного за ранг:от 50% до 70%.", "max_level":4, "requires":{"storage":1}, "branch":"economy","position":Vector2(290,1040),"color":Color("9ece86")},
		{"id":"memory_vault", "name":"Несгораемая память", "description":"Ещё +10% добычи после поражения. Вместе с мешками — максимум 80%.", "max_level":1, "requires":{"salvage":3, "heart":3}, "branch":"economy","position":Vector2(530,1045),"color":Color("9ece86")},
		{"id":"victory_dividend", "name":"Сортировка добычи", "description":"Успешная вылазка приносит на 5% больше биомассы, ткани и фермента за ранг. Ядра не умножаются.", "max_level":3, "requires":{"storage":2}, "branch":"economy","position":Vector2(750,995),"color":Color("9ece86")},
		{"id":"quarantine_door", "name":"Карантинная камера", "description":"Открывает новый изолированный отсек на юго-западе. Там выбираются рискованные протоколы вылазок.", "max_level":1, "requires":{"regeneration":1,"heart":1}, "branch":"rooms","position":Vector2(290,520),"color":Color("ba95dc")},
		{"id":"swarm_protocol", "name":"Протокол: рой", "description":"В карантине можно включить более частые волны: +25% темпа, +25% обычных ресурсов при успехе.", "max_level":1, "requires":{"quarantine_door":1}, "branch":"rooms","position":Vector2(520,455),"color":Color("ba95dc")},
		{"id":"predator_protocol", "name":"Протокол: хищники", "description":"В карантине можно выбрать +25% здоровья всем врагам и +50% ткани и фермента при успехе. Одновременно активен один протокол.", "max_level":1, "requires":{"quarantine_door":1,"heart":2,"regeneration":2}, "branch":"rooms","position":Vector2(750,560),"color":Color("ba95dc")},
		{"id":"recycler", "name":"Питательный фильтр", "description":"При успешном возвращении дополнительно +2 ткани за ранг.", "max_level":3, "requires":{"refinery_door":1,"regeneration":3}, "branch":"rooms","position":Vector2(980,700),"color":Color("ba95dc")},
		{"id":"logistics", "name":"Грузовые сосуды", "description":"При успешном возвращении дополнительно +5 биомассы за ранг.", "max_level":3, "requires":{"victory_dividend":1, "storage":3}, "branch":"economy","position":Vector2(980,1015),"color":Color("9ece86")},
		{"id":"living_legacy", "name":"Венец: пробуждение", "description":"Полностью связанный корабль: +20% биомассы после успешной вылазки; сердце получает яркий живой пульс.", "max_level":1, "requires":{"heart":4,"blackbox":1,"core_synthesis":1,"predator_protocol":1,"navigation":4,"regeneration":4,"storage":4}, "branch":"heart","position":Vector2(1220,370),"color":Color("e49b77")},
	]
	var result := {}
	for node: Dictionary in rows:
		node["costs"] = _costs(2 if node["requires"].is_empty() else (5 if str(node["id"]) == "living_legacy" else 3),int(node["max_level"]))
		result[node["id"]] = node
	# Preserve prices of all four original investments.
	result["heart"]["costs"] = [[25,0,5,0],[50,0,12,1],[75,12,20,2],[100,20,30,3]]
	result["navigation"]["costs"] = [[18,3,5,0],[32,6,9,1],[50,10,15,1],[75,15,24,2]]
	result["regeneration"]["costs"] = [[20,4,3,0],[35,8,6,1],[55,12,10,1],[80,18,18,2]]
	result["storage"]["costs"] = [[16,4,2,0],[28,8,5,0],[45,12,9,1],[65,20,15,2]]
	return result

static func traits(nodes: Dictionary, levels: Dictionary) -> Dictionary:
	var result := {}
	for id: String in nodes:
		var rank := clampi(int(levels.get(id,0)),0,int(nodes[id]["max_level"]))
		for key: String in nodes[id].get("effects",{}):
			result[key] = float(result.get(key,0.0)) + float(nodes[id]["effects"][key])*rank
	return result
