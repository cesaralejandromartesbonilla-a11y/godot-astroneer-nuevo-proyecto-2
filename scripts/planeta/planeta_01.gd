extends VoxelLodTerrain

# El generador del planeta es el grafo estático planeta_01.tres.
#
# IMPORTANTE (F1, lección de los depósitos flotantes): NO mutar las seeds de los
# ruidos en runtime. El grafo se compila al deserializar el .tres con las seeds
# por defecto del recurso; mutarlas después solo afecta a quien muestree el objeto
# (p. ej. ore_deposit_placer) y NO al terreno ya compilado → superficies distintas.
# El terreno es determinista porque el .tres es estático; Global.world_seed gobierna
# únicamente las vetas (OreField). Si algún día se quieren seeds por planeta, hay que
# escribirlas DENTRO del .tres (o generar el grafo por código y compilarlo), nunca
# mutar en _ready. Ver ROADMAP §2.4.

@export var radius := 250.0
@export var world_seed := 0
