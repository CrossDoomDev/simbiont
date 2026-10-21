class_name GardenData
extends RefCounted
## A resource/cultivation/optional-hunt loop; never a character stat multiplier.
const CULTURES := {
	"vascular":{"name":"Кровяная лоза","row":0,"cost":[24,4,0,0],"growth":3,"digest":[60,10,0,0],"hunt":[70,18,3,0],"color":Color("df97b4")},
	"enzyme":{"name":"Ферментный цветок","row":1,"cost":[18,0,4,0],"growth":6,"digest":[10,0,18,0],"hunt":[25,6,30,0],"color":Color("8cdbdd")},
	"core":{"name":"Ядерный кокон","row":2,"cost":[35,12,8,0],"growth":9,"digest":[0,0,0,1],"hunt":[20,12,10,2],"color":Color("ecc47c")},
}

static func empty_beds() -> Array:
	return [{"strain":"","growth":0},{"strain":"","growth":0},{"strain":"","growth":0}]

static func stage(bed: Dictionary) -> int:
	var id := str(bed.get("strain",""))
	if not CULTURES.has(id):
		return 0
	var progress: float = float(bed.get("growth",0))/float(CULTURES[id]["growth"])
	return 3 if progress >= 1.0 else (2 if progress >= 0.5 else (1 if progress > 0 else 0))
