# import itertools
import random
import time
# import pprint

def kort_stokk():
    global typeS, kort_figurer, kort_tall
    kort_tall = [ 1 , 2 , 3 , 4 , 5 , 6 , 7 , 8 , 9 , 10 , 11 , 12 , 13 ]
    kort_figurer = [ "A" , 2 , 3 , 4 , 5 , 6 , 7 , 8 , 9 , 10 , "J" , "Q" , "K" ]
    typeS = ["♣", "♦" , "♥" , "♠"]
    stokk = []
    for figur in typeS:
        for tall in kort_tall:
            stokk.append((figur, tall))
    return stokk


def spill():
    start = " "
    while start not in "jn":
        start = input("Starte et nytt spill? (j/n) ")
    if start == "j":
        hender = intro()
        stokk = kort_stokk()
        try:
            hender, stokk = farge(hender, stokk)
            hender, stokk = over_under(hender, stokk)
            hender, stokk = mellom_eller_utenfor(hender, stokk)
            hender, stokk = krhs(hender, stokk)
            taper = pyramide(hender, stokk)
            bussruta(taper)
            spill()
        except:
            spill()
    return


def intro():
    print('''
                           Velkommen til bussruta!

    -------------------- REGLER FOR SPILL AV BUSSRUTA --------------------
          
    Spillet starter med en "oppvarming" for å se hvem som tar ruta.

    Gjetter du riktig kan du dele ut slurker, feil må du drikke selv.

    Runde 1: Gjett farge på kort, 1 slurk
    Runde 2: Gjett over eller under første kortet, 2 slurker
    Runde 3: Gjett mellom eller utenfor dine tidligere kort, 3 slurker
    Runde 4: Gjett hvilken sort du trekker, 4 slurker
          
    I runde 1 og 2 er det også mulig å velge "samme",
    high risk, high reward
          
    Den som har flest kort igjen etter rundene må ta bussruta.

                                Lykke til!
          
    ----------------------------------------------------------------------
          
        // Skriv: " q " om dere vil restarte spillet, når som helst //
        ''')

    spillere = []
    antall = ""
    try:
        antall = int(input("Hvor mange er det som skal spille?: "))
    except:
        while type(antall) != int and antall >= 9:
            antall = int(input("Må være et tall mellom 1 og 9: "))                  

    for i in range(antall):
        navn = input(f"Navn på spiller {i + 1}: ")
        if navn in spillere:
            while navn in spillere:
                navn = input(f"Det navnet er tatt, spiller {i + 1}, du må velge et annet navn: ")
        if len(navn) < 1:
            while navn < 1:
                navn = input(f"Du må ha minst en karakter i navnet ditt, spiller {i + 1}, velg et annet navn: ")
        spillere.append(navn)
    print("")
    print(f"starter et spill for {len(spillere)} spillere....")
    hender = {}
    for person in spillere:
        hender[person] = []
    return hender


def trekk_kort(stokk):
    trekk = random.choice(stokk)
    stokk.remove(trekk)
    index = kort_tall.index(trekk[1])
    print(f"Det ble trukket: {kort_figurer[index]}{trekk[0]}")
    return trekk, stokk

def print_hånd(person, hender):
    hånd = f"På din hånd {person}, har du:"
    for kort in hender[person]:
        index = kort_tall.index(kort[1])
        hånd += f" {kort_figurer[index]}{kort[0]}"
    if hånd == f"På din hånd {person}, har du:":
        hånd = f"{person} har ingen kort igjen og er ute av faresonen"
    return hånd

def print_hender(hender):
    for person in hender:
        print(print_hånd(person, hender))
        print("")


def farge(hender, stokk):
    print("")
    print('''
         ----------------------------------------------------------------------''')
    print('''                
                    Nå skal dere gjette hvilken farge dere trekker!
        ''')
    for person in hender:
        time.sleep(1)
        print(f"{person} sin tur, hva gjetter du?")
        gjett = ""
        while gjett not in ["svart", "rødt"]:
            gjett = input("svart eller rødt? ").lower()
            if gjett == "q":
                return

        trekk , stokk = trekk_kort(stokk)
        hender[person].append(trekk)
        t = trekk[0]

        if t == "♣" or t == "♠":
            farge = "svart"
        elif t == "♦" or t == "♥":
            farge = "rødt"

        if gjett == farge:
            print(f"Riktig, det ble {farge}! Del ut 1 slurk." )
            print("")
        else:
            print(f"Feil, det ble {farge}... Du må drikke 1 slurk selv. ")
            print("")
    return hender, stokk


def over_under(hender, stokk):
    print('''
        ----------------------------------------------------------------------''')
    print('''                           
                                 Over eller under!
        ''')
    for person in hender:
        # time.sleep(1)
        hånd = print_hånd(person, hender)
        print(f"{person} sin tur, hva gjetter du? ")
        print(hånd)
        
        gjett = ""
        while gjett not in ["over", "under", "samme"]:
            gjett = input("over eller under? ").lower()
            if gjett == "q":
                return
        trekk , stokk = trekk_kort(stokk)
        hender[person].append(trekk)


        if trekk[1] > hender[person][0][1] and gjett == "over":
            print("Riktig, det ble over! Del ut 2 slurker.")
        elif trekk[1] < hender[person][0][1] and gjett == "under":
            print("Riktig, det ble under! Del ut 2 slurker.")
        elif trekk[1] == hender[person][0][1] and gjett == "samme":
            print("Gullhår i ræva, det ble det samme! Del ut 4 slurker.")

        elif trekk[1] > hender[person][0][1] and gjett == "under":
            print("Feil, det ble over! Drikk 2 slurker.")
        elif trekk[1] < hender[person][0][1] and gjett == "over":
            print("Feil, det ble under! Drikk 2 slurker.")
        elif trekk[1] == hender[person][0][1]:
            print("Feil, det ble det samme! Drikk 4 slurker.")
        print("")
    return hender, stokk


def mellom_eller_utenfor(hender, stokk):
    print('''
        ----------------------------------------------------------------------''')
    print('''
                                Mellom eller utenfor!
        ''')

    for person in hender:
        # time.sleep(1)
        hånd = print_hånd(person,hender)
        print(f"{person} sin tur, hva gjetter du? ")
        print(hånd)
        gjett = ""
        while gjett not in ["mellom", "utenfor", "samme"]:
            gjett = input("Mellom eller utenfor? ").lower()
            if gjett == "q":
                return spill()
        trekk , stokk = trekk_kort(stokk)
        hender[person].append(trekk)

        første = int(hender[person][0][1])
        andre = int(hender[person][1][1])
        tidligere = [første, andre]
        tidligere.sort()

        if gjett == "samme":
            if trekk[1] == min(tidligere) or trekk[1] == max(tidligere):
                print("Riktig, det ble samme! Del ut 6 slurker.")
            else:
                print("Det var leit, drikk 3 slurker selv.")
        if trekk[1] == min(tidligere) or trekk[1] == max(tidligere):
            if gjett != "samme":
                print("Det var leit, det ble dedt samme. Drikk 6 slurker selv.")

        if gjett == "mellom":
            if trekk[1] > min(tidligere) and trekk[1] < max(tidligere):
                print("Riktig, det ble mellom. Del ut 3 slurker.")
            else:
                print("Feil, det ble utenfor. Del ut 3 slurker.")

        if gjett == "utenfor":
            if trekk[1] < min(tidligere) or trekk[1] > max(tidligere):
                print("Riktig, det ble utenfor. Del ut 3 slurker.")
            else:
                print("Feil, det ble mellom. Del ut 3 slurker.")
        print("")

    return hender, stokk


def krhs(hender, stokk):
    print('''
        ----------------------------------------------------------------------''')
    print('''            
            Da er det tid for å gjette kløver, ruter, hjerter eller spar
        ''')
    for person in hender:
        time.sleep(1)
        hånd = print_hånd(person,hender)
        print(f"{person} sin tur, hva gjetter du?")
        print(hånd)
        gjett = ""
        typer = ["kløver", "ruter", "hjerter", "spar"]
        while gjett not in typer:
            gjett = input("Hvilken sort tror du? ").lower()

            if gjett == "q":
                return spill()

        index_gjett = typer.index(gjett)
        # print(f"Du har valgt: {typeS[index_gjett]}.")

        trekk , stokk = trekk_kort(stokk)
        index = typeS.index(trekk[0])
        hender[person].append(trekk)

        if index_gjett == index:
            print("Heldiggris, det var riktig! Del ut 4 slurker.")
        else:
            print(f"Synd, det ble {trekk[0]}. Drikk fire slurker selv.")
        print("")

    return hender, stokk


def pyramide(hender, stokk):
    time.sleep(1)
    a,b,c,d,e,f,g,h,i,j,k,l,m,n,o = "*","*","*","*","*","*","*","*","*","*","*","*","*","*","*"
    trekant = [a,b,c,d,e,f,g,h,i,j,k,l,m,n,o]
    trekant.reverse()
    print('''
    ----------------------------------------------------------------------''')
    print('''          
        Da har vi kommet oss til pyramiden, la oss se hva dere har på hånden.''')
    print_pyramide(trekant)
    print("")

    print_hender(hender)
    time.sleep(1)

    for i in range(len(trekant)):
        print('''    ----------------------------------------------------------------------
        ''')
        nytt_kort, stokk = trekk_kort(stokk)

        trekant[i] = nytt_kort
        time.sleep(3)
        print_pyramide(trekant)
        time.sleep(1)

        if i == 14:
            index = 5
        if i < 14:
            index = 4
        if i < 12:
            index = 3
        if i < 9:
            index = 2
        if i < 5:
            index = 1
        
        figur = kort_tall.index(nytt_kort[1])
        fjernes = []
        sjekk = False

        for person in hender:
            ganger = 0
            fjernes = []
            for kort in hender[person]:
                time.sleep(0.5)   
                if kort[1] == nytt_kort[1]:
                    ganger += 1
                    fjernes.append(kort)

            if ganger >= 1:
                for hånd in fjernes:
                    hender[person].remove(hånd)
                # time.sleep(1)

                print("")
                if ganger > 2:
                    print(f"{person} hadde {ganger} : {kort_figurer[figur]}er(e), og kan dele ut {index * ganger} slurker")
                else:
                    if index > 1:
                        slurk = "slurker"
                    else:
                        slurk = "slurk"
                    print(f"{person} hadde {kort_figurer[figur]}, og kan dele ut {index} {slurk}")
                print("")
                sjekk = True
        time.sleep(1)
        if sjekk == False:
            print(f"Ingen hadde {kort_figurer[figur]}, spillet går videre.")
            time.sleep(2)
        print('''    
    ----------------------------------------------------------------------''')

        print_hender(hender)
        time.sleep(5) #Dette er hvor lang tid til neste pyramide blir laget

    print('''    
    ------------------------- pyramiden er ferdig ------------------------- 
    ''')
    time.sleep(3)
    taper = sjekk_taper(hender)
    return taper


def print_pyramide(trekant):
    visning = trekant.copy()
    for i in range(len(trekant)):
        if "*" in visning[i]:
            if " " not in visning[i]:
                trekant[i] += " "
        else:
            try:
                element = trekant[i]
                index = kort_tall.index(element[1])
                visning[i] = f"{kort_figurer[index]}{element[0]}"
            except:
                visning[i] = f"{visning[1]}{visning[0]}"          
    print('''
    ----------------------------------------------------------------------''')
    print(f'''

                                      
                                     ^
                                    / {visning[14]}
                                    
                                  / {visning[12]}   {visning[13]}
                                
                                / {visning[9]}   {visning[10]}   {visning[11]}
                                
                              / {visning[5]}   {visning[6]}   {visning[7]}   {visning[8]}
                     
                            / {visning[0]}   {visning[1]}   {visning[2]}   {visning[3]}   {visning[4]}
                           _ _  __  ____   __ _ __  _


    ----------------------------------------------------------------------        
        ''')


def sjekk_taper(hender):
    taper_liste = []
    tidligere = 0
    for person in hender:
        mengde = len(hender[person])
        if mengde > tidligere:
            tidligere = mengde
            taper_liste.clear()
            taper_liste.append(".")
            taper_liste.append(person)
        elif mengde == tidligere:
            taper_liste.append(person)

    if len(taper_liste) > 2:
        print(f"oooooo spennende det er flere spillere med {tidligere} kort igjen...")
        print("")
        time.sleep(1)
        for i in range(1,len(taper_liste)-1):
            print(taper_liste[i])
            time.sleep(1)
        print("En av dere blir valgt tilfeldig nå....")
        taper = taper_liste[random.randint(1, len(taper_liste))]
    else:
        taper = taper_liste[1]
    time.sleep(1)
    print("")
    print(f"Den heldige vinneren av denne rulingen, med {tidligere} kort er... ")
    print("")
    time.sleep(3)
    print(f"{taper}, gratulerer! Du skal nå videre til bussruta.")

    return taper


def bussruta(taper):
    print('''
    ----------------------------------------------------------------------''')
    print(f'''
                        velkommen til bussruta, {taper}.
    ''')
    stokk = kort_stokk()

    liste = []
    for i in range(5):
        trekk, stokk = trekk_kort(stokk)
        liste.append(trekk)

    over = "                     "
    midten = "                    "
    under = "                     ^"

    trekk = ["over","under","samme","q"]
    brukt = []
    for kort in liste:
        try:
            index = kort_tall.index(kort[1])
            kortet = f"{kort_figurer[index]}{kort[0]}"
        except:
            kortet = f"{kort[1]}{kort[0]}"  
        if kort[1] == 10:
         midten += " " + kortet + " "       
        else:
         midten += " " + kortet + "  "
    iterasjon = 0
    første = True

    while True:
        iterasjon += 1
        if len(stokk) < 1:
            print(f"Kortstokken er tom og du har tapt fullstendig, {taper}")
            return
        visning = ""
        valg = ""

        if len(brukt) == 5:
            under = under.rstrip(under[-1])
        print_ruta(over,midten,under,iterasjon)

        if len(brukt) == 5:
            if not første:
                print("For en soldat du er!")
                print("")
                print("Spillet er ferdig, men det er mulig å spille mer.")
                print("")

            else:
                print(f"Gratulerer {taper}, det var første forsøk!")
                print("")
                print("Resten av spillerene må chugge enheten sin, og spillet er ferdig!")
            return

        while valg not in trekk:
            valg = input("over eller under? ")
        if valg == "q":
            print("force quit")
            return

        kort, stokk = trekk_kort(stokk)
        try:
            index = kort_tall.index(kort[1])
            visning = f"{kort_figurer[index]}{kort[0]}"
        except:
            visning = f"{kort[1]}{kort[0]}"

        if valg == "under" and kort[1] < liste[iterasjon - 1][1]:
            under = under.rstrip(under[-1])
            if kort[1] == 10:
                under +=  visning + "  ^"
            else:
                under +=  visning + "   ^"
            over = over + "     "
            brukt.append(visning)

        elif valg == "over" and kort[1] > liste[iterasjon - 1][1]:
            under = under.rstrip(under[-1])
            if kort[1] == 10:
                over += visning + "  "
            else:
                over += visning + "   "

            under =  under + "     ^"
            brukt.append(visning)

        elif valg == "samme" and kort[1] == liste[iterasjon -1][1]:
            under = under.rstrip(under[-1])
            print("Heldiggris")
            over += "       "
            under =  under + "     ^"
            brukt.append(visning)

        elif kort[1] == liste[iterasjon -1][1] and iterasjon > 1:
            print(f"Dessverre trakk du {visning}.")
            print(f"Uflaks, men du starter på samme sted igjen. Drikk {iterasjon} slurker.")
            iterasjon -= 1

        else:
            første = False
            slurk = "slurk"
            if iterasjon > 1:
                slurk = "slurker"
            print(f"Det var synd, drikk {iterasjon} {slurk}")
            iterasjon = 0
            over = "                     "
            under = "                     ^"
            brukt = []


def print_ruta(over,midten,under,iterasjon):
    iterasjon += 1
    print(f'''
    ----------------------------------------------------------------------

                                Over eller under?

        {over}
        {midten}
        {under}
    ''')   
    return iterasjon

spill()
# bussruta("Julie")
