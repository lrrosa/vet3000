"""32 original Arkanoid-inspired courts, 15 columns x 10 rows.

`.` empty, `#` normal, `S` two hits, `G` indestructible. Gold is deliberately
broken into short islands: never a closed roof trapping the remaining bricks.
"""


def court(name, shape, silver=lambda x, y: False, gold=lambda x, y: False):
    rows = ["".join("G" if gold(x, y) else "S" if silver(x, y) else "#"
                    if shape(x, y) else "." for x in range(15)) for y in range(10)]
    return name, rows


COURTS = [
    court("PRIMEIRO CONTATO", lambda x,y: y < 6, lambda x,y: y == 0),
    court("ESCADARIA", lambda x,y: y < 2 + x//2, lambda x,y: y == x//2),
    court("PIRAMIDE", lambda x,y: abs(x-7) <= y, lambda x,y: y == 8 and 3 <= x <= 11),
    court("QUATRO TORRES", lambda x,y: x%4 < 2 and y < 8, lambda x,y: y == 7 and x%4 < 2),
    court("DIAMANTE", lambda x,y: abs(x-7)+abs(y-4) < 7, lambda x,y: abs(x-7)+abs(y-4) == 6),
    court("PASSAGENS", lambda x,y: y%3 != 2 and x%5 != 2,
          gold=lambda x,y: y == 8 and x in (2,3,7,8,12,13)),
    court("INVASOR", lambda x,y: (y in (1,2) and x in (3,4,10,11)) or
          (3 <= y <= 6 and 2 <= x <= 12 and not (y == 4 and x in (5,9))) or
          (y == 8 and x in (3,4,6,8,10,11)), lambda x,y: y == 6 and 5 <= x <= 9),
    court("PONTE DE OURO", lambda x,y: y < 5 and 1 <= x <= 13,
          lambda x,y: y == 4 and x%2 == 0, lambda x,y: y == 7 and 3 <= x <= 11),
    court("ZIGUEZAGUE", lambda x,y: (x+2*y)%8 < 4, lambda x,y: y == 8 and x%3 == 0),
    court("AMPULHETA", lambda x,y: abs(x-7) <= abs(y-4), lambda x,y: y in (0,9) and 3 <= x <= 11),
    court("CASTELO", lambda x,y: (y<2 and x%4<2) or (2<=y<=7 and not (y>=5 and 6<=x<=8)),
          lambda x,y: y == 3 and x%2 == 0),
    court("ANEL ABERTO", lambda x,y: 4 <= abs(x-7)+abs(y-4) <= 7,
          gold=lambda x,y: x in (3,11) and 3<=y<=5),
    court("TRES CAMINHOS", lambda x,y: x in (1,2,6,7,8,12,13),
          lambda x,y: y in (3,7) and x in (1,2,6,7,8,12,13)),
    court("X CRUZADO", lambda x,y: abs(x-y-2)<2 or abs(x+y-12)<2,
          lambda x,y: y == 4 and 5<=x<=9),
    court("MAR DE TIJOLOS", lambda x,y: y <= (x%5)+3,
          lambda x,y: y == (x%5)+3, lambda x,y: y == 8 and x%5 == 2),
    court("GUARDIOES", lambda x,y: y<5 and x%4!=3,
          lambda x,y: y == 4 and x%4!=3, lambda x,y: y in (6,7) and x in (3,7,11)),
    court("CORACAO", lambda x,y: (y<3 and 1<=x<=13 and not (y==0 and 6<=x<=8)) or
          (3<=y<=8 and abs(x-7)<=8-y), lambda x,y: y==3 and x in (4,10)),
    court("FLECHAS", lambda x,y: abs((x%5)-2)<=y%5,
          lambda x,y: y in (4,9) and x%5==2),
    court("COLMEIA", lambda x,y: (x+3*(y//2))%6<4 and y%3!=2,
          gold=lambda x,y: y in (2,5,8) and x in (2,8,14)),
    court("FORTALEZA", lambda x,y: (y<6 and x%5!=2) or (y==8 and 4<=x<=10),
          lambda x,y: y==5 and x%5!=2, lambda x,y: y==7 and x in (1,2,6,7,11,12)),
    court("ORBITAS", lambda x,y: (abs(x-7)+2*abs(y-4))%5<2,
          lambda x,y: y==4 and x in (2,7,12)),
    court("LABIRINTO", lambda x,y: (y%3==0 and x not in (2,7,12)) or (x%5==0 and y%3!=2),
          gold=lambda x,y: x in (4,10) and y in (2,3,6,7)),
    court("ASAS", lambda x,y: 2<=abs(x-7)<=7-y//2,
          lambda x,y: y==7 and x in (3,4,10,11)),
    court("CHUVA DOURADA", lambda x,y: y<5 and (x+y)%3!=0,
          gold=lambda x,y: y in (6,8) and (x+2*y)%6==0),
    court("CIRCUITO", lambda x,y: (y in (0,3,6,9) and x%4!=1) or (x%4==0 and y%3!=1),
          lambda x,y: y==9 and x%4!=1),
    court("DOIS NUCLEOS", lambda x,y: min(abs(x-3),abs(x-11))+abs(y-4)<=4,
          lambda x,y: y==4 and x in (3,11), lambda x,y: x==7 and y in (1,2,6,7)),
    court("SERPENTE", lambda x,y: abs(x-(2+2*(y if y<5 else 9-y)))<3,
          lambda x,y: y in (4,5) and 8<=x<=12),
    court("PORTAIS", lambda x,y: y<6 and (x<5 or x>9),
          lambda x,y: y==5 and (x<5 or x>9), lambda x,y: x in (5,9) and y in (2,3,7,8)),
    court("ESTRELA", lambda x,y: abs(x-7)<=1 or abs(y-4)<=1 or abs(x-7)==abs(y-4),
          lambda x,y: y in (0,8) and 6<=x<=8),
    court("MURALHAS", lambda x,y: y%3<2 and (x+y//3)%5!=0,
          lambda x,y: y in (1,4,7) and (x+y//3)%5!=0),
    court("ULTIMA BARREIRA", lambda x,y: y<7 and x%4!=3,
          lambda x,y: y in (3,6) and x%4!=3, lambda x,y: y==8 and x in (1,2,5,6,9,10,13)),
    court("REATOR", lambda x,y: abs(x-7)+abs(y-4)<=6,
          lambda x,y: 2<=abs(x-7)+abs(y-4)<=4,
          lambda x,y: x in (2,12) and y in (2,3,5,6)),
]
LEVELS = [rows for _, rows in COURTS]
assert len(LEVELS) == 32 and len({tuple(rows) for rows in LEVELS}) == 32
assert all(len(rows)==10 and all(len(row)==15 for row in rows) for rows in LEVELS)
