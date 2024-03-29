��          �   %   �      p     q  s   s    �  �   �  �   �  �   ;  k   �  �   g  k      N   �  _   �  E   ;  &   �  '   �  '   �  �   �  _   �	     0
     B
     Z
  E   p
  ,   �
  +   �
  %        5  +   C     o  �  �     e     g  �   �  �   �  �   j  �   J  \     �   r  �   O  r   �  ~   E  h   �  .   -  7   \      �  �   �  T   �     �     �  #     U   6  *   �  (   �  "   �       <         ]     	                                                                                               
                       
   --debug, -d
    Print information on the screen that might be
    useful for diagnosing and/or solving problems.
   --description <description|file>, -D <description|file>
    Provide a descriptive name for the command to
    be used in the default message, making it nicer.
    You can also provide the absolute path for a
    .desktop file. The Name key for will be used in
    this case.
   --disable-grab, -g
    Disable the "locking" of the keyboard, mouse,
    and focus done by the program when asking for
    password.
   --login, -l
    Make this a login shell. Beware this may cause
    problems with the Xauthority magic. Run xhost
    to allow the target user to open windows on your
    display!
   --message <message>, -m <message>
    Replace the standard message shown to ask for
    password for the argument passed to the option.
    Only use this if --description does not suffice.
   --preserve-env, -k
    Preserve the current environments, does not set $HOME
    nor $PATH, for example.
   --print-pass, -p
    Ask gksu to print the password to stdout, just
    like ssh-askpass. Useful to use in scripts with
    programs that accept receiving the password on
    stdin.
   --prompt, -P
    Ask the user if they want to have their keyboard
    and mouse grabbed before doing so.
   --su-mode, -w
    Make GKSu use su, instead of using libgksu's
    default.
   --sudo-mode, -S
    Make GKSu use sudo instead of su, as if it had been
    run as "gksudo".
   --user <user>, -u <user>
    Call <command> as the specified user.
 <b>Failed to request password.</b>

%s <b>Failed to run %s as user %s.</b>

%s <b>Incorrect password... try again.</b> <b>Would you like your screen to be "grabbed"
while you enter the password?</b>

This means all applications will be paused to avoid
the eavesdropping of your password by a a malicious
application while you type it. <big><b>Missing options or arguments</b></big>

You need to provide --description or --message. GKsu version %s

 Missing command to run. Open as administrator Opens a terminal as the root user, using gksu to ask for the password Opens the file with administrator privileges Option not accepted for --disable-grab: %s
 Option not accepted for --prompt: %s
 Root Terminal Usage: %s [-u <user>] [options] <command>

 User %s does not exist. Project-Id-Version: gksu-lt
Report-Msgid-Bugs-To: kov@debian.org
POT-Creation-Date: 2007-05-11 00:59-0300
PO-Revision-Date: 2006-08-03 13:03+0300
Last-Translator: Gintautas Miliauskas <gintas@akl.lt>
Language-Team: Lithuanian <komp_lt@konferencijos.lt>
MIME-Version: 1.0
Content-Type: text/plain; charset=UTF-8
Content-Transfer-Encoding: 8bit
X-Generator: KBabel 1.11.2
Plural-Forms:  nplurals=3; plural=(n%10==1 && n%100!=11 ? 0 : n%10>=2 && (n%100<10 || n%100>=20) ? 1 : 2);
 
   --debug, -d
    Išvesti ekrane papildomą informaciją, kuri gali būti
    naudinga nustatant arba sprendžiant problemas.
   -- description <aprašymas|failas>, -D <aprašymas|failas>
    Nurodyti aprašomajį pavadinimą komandai, kuris bus
    naudojamas pranešime. Taip pat galite nurodyti kelią
    iki .desktop failo, tada pavadinimui bus naudojamas
    Name laukas.
   --disable-grab, -g
    Uždrausti klaviatūros, pelės ir židinio perėmimą,
    kurį atlieka programa klausdama slaptažodžio.
   --login, -l
    Padaryti šį apvalkalą prisijungimo (login shell). Atsargiai, tai gali
    sukelti problemų su Xauthority magija. Įvykdykite „xhost“,
    kad taip paleista programa galėtų atverti langus ekrane.
   --message <žinutė>, -m <žinutė>
    Pakeisti standartinę žinutę, rodomą klausiant
    slaptažodžio, į argumente nurodytą žinutę.
    Naudokite tik jei nepakanka --description argumento.
   --preserve-env, -k
    Išsaugoti aplinkos kintamuosius. Pvz., nekeis
    $HOME ir $PATH.
   --print-pass, -p
    Paprašyti, kad gksu išvestų slaptažodį į standartinį išvedimą,
    kaip kad ssh-askpass. Naudinga rašant scenarijus programoms,
    kurios priima slaptažodį per standartinį įėjimą.
   --prompt, -P
    Klausti naudotojo, ar jis nori, kad klaviatūros ir pelės
    židinys būtų perimtas, prieš tai atliekant.
   --sudo-mode, -S
    Nurodyti, kad GKSu naudotų „su“, užuot naudojusi
    libgksu standartinį nustatymą.
   --sudo-mode, -S
    Nurodyti, kad GKSu naudotų „sudo“ vietoj „su“,
    tarsi ji būtų paleista kaip „gksudo“.
   --user <naudotojo vardas>, -u <naudotojo vardas>
    Vykdyti <komandą> nurodyto naudotojo teisėmis.
 <b>Nepavyko užklausti slaptažodžio.</b>

%s <b>Nepavyko vykdyti %s naudotojo %s teisėmis:</b>

 %s <b>Neteisingas slaptažodis.</b> <b>Ar norėtumėte, kad jūsų ekranas būtų "perimtas"
slaptažodžio įvedimo metu?</b>

Tai reiškia, kad visos programos bus trumpam sustabdytos,
todėl piktybiškos programos negalės nuskaityti slaptažodžio. <big><b>Trūksta argumentų</b></big>

Reikia nurodyti --description arba --message. GKsu versija %s

 Nenurodyta komanda vykdymui. Atverti administratoriaus teisėmis Atveria terminalą 'root' naudotojo teisėmis, naudojant gksu slaptažodžiui įvesti Atveria failą administratoriaus teisėmis Parinktis nepriimta: --disable-grab: %s
 Parinktis nepriimta: --prompt: %s
 Administratoriaus terminalas Naudojimas: %s [-u <naudotojo vardas>] [-k] [-l] <komanda>

 Naudotojas %s neegzistuoja. 