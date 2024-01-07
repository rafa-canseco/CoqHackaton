import random

# Definir el mazo original
mazo_original = [
    "1 de Oro", "2 de Oro", "3 de Oro", "4 de Oro", "5 de Oro", "6 de Oro", "7 de Oro", "10 de Oro", "11 de Oro", "12 de Oro",
    "1 de Espada", "2 de Espada", "3 de Espada", "4 de Espada", "5 de Espada", "6 de Espada", "7 de Espada", "10 de Espada", "11 de Espada", "12 de Espada",
    "1 de Copa", "2 de Copa", "3 de Copa", "4 de Copa", "5 de Copa", "6 de Copa", "7 de Copa", "10 de Copa", "11 de Copa", "12 de Copa",
    "1 de Basto", "2 de Basto", "3 de Basto", "4 de Basto", "5 de Basto", "6 de Basto", "7 de Basto", "10 de Basto", "11 de Basto", "12 de Basto"
]

# Pista inicial con los caballos en la posición 0
pista = [0, 0, 0, 0]

# Crear el mazo de penitencia vacío
mazo_penitencia = []

# Barajar el mazo original
random.shuffle(mazo_original)

# Función para mostrar la pista
def mostrar_pista():
    print("Pista: ", end="")
    for i, caballo in enumerate(pista):
        if caballo >= 11:
            print(f"Caballo {i + 1} - ¡Ganador!")
        else:
            print(f"Caballo {i + 1}: {caballo}", end="   ")
    print()

# Juego principal
while True:
    # Verificar si el mazo original está vacío y tomar las cartas del mazo basura
    if len(mazo_original) == 0:
        mazo_original = mazo_penitencia.copy()
        random.shuffle(mazo_original)
        mazo_penitencia = []

    # Sacar una carta del mazo original y colocarla en el mazo basura
    carta = mazo_original.pop()
    print("Carta del turno:", carta)
    mazo_penitencia.append(carta)

    # Obtener el palo de la carta
    palo = carta.split(" de ")[1]

    # Verificar si el caballo correspondiente al palo avanza
    if palo == "Oro":
        pista[0] += 1
    elif palo == "Espada":
        pista[1] += 1
    elif palo == "Copa":
        pista[2] += 1
    elif palo == "Basto":
        pista[3] += 1

    # Mostrar la pista actualizada
    mostrar_pista()

    # Verificar si el último caballo avanza y revelar una carta del mazo de penitencia
    if pista.count(pista[-1]) == 1:
        if len(mazo_penitencia) == 0:
            mazo_penitencia = mazo_original.copy()
            random.shuffle
            mazo_penitencia
            mazo_original = []

        carta_penitencia = mazo_penitencia.pop()
        print("Carta del mazo de penitencia:", carta_penitencia)
        mazo_penitencia.append(carta_penitencia)

        # Obtener el palo de la carta de penitencia
        palo_penitencia = carta_penitencia.split(" de ")[1]

        # Verificar si el caballo correspondiente al palo de penitencia disminuye su posición
        if palo_penitencia == "Oro":
            pista[0] -= 1
        elif palo_penitencia == "Espada":
            pista[1] -= 1
        elif palo_penitencia == "Copa":
            pista[2] -= 1
        elif palo_penitencia == "Basto":
            pista[3] -= 1

        # Mostrar la pista actualizada
        mostrar_pista()

    # Verificar si algún caballo ha llegado a la posición 11 y finalizar el juego
    if 11 in pista:
        ganador = pista.index(11) + 1
        print(f"¡El caballo {ganador} ha ganado!")
        break
