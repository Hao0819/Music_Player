import subprocess, sys, os
from fontTools.ttLib import TTFont
from fontTools.varLib.instancer import instantiateVariableFont

SRC = "Archivo-Variable.ttf"
# Latin + Latin Extended-A, punctuation, currency, arrows used in the UI.
UNI = ("U+0000-00FF,U+0100-017F,U+0180-024F,U+0259,U+1E00-1EFF,"
       "U+2000-206F,U+2070-209F,U+20A0-20BF,U+2122,U+2190-2193,U+2212,"
       "U+25CF,U+2605,U+FB00-FB04,U+FEFF,U+FFFD")

CUTS = [
    ("Archivo-Regular.ttf",          {"wght": 400, "wdth": 100}),
    ("Archivo-Medium.ttf",           {"wght": 500, "wdth": 100}),
    ("Archivo-SemiBold.ttf",         {"wght": 600, "wdth": 100}),
    ("Archivo-Bold.ttf",             {"wght": 700, "wdth": 100}),
    ("ArchivoExpanded-ExtraBold.ttf",{"wght": 800, "wdth": 125}),
]

for name, loc in CUTS:
    f = TTFont(SRC)
    instantiateVariableFont(f, loc, inplace=True, updateFontNames=False)
    tmp = name + ".tmp"
    f.save(tmp)
    subprocess.run([sys.executable, "-m", "fontTools.subset", tmp,
                    f"--unicodes={UNI}", "--layout-features=kern,liga,calt,tnum",
                    "--drop-tables+=DSIG", f"--output-file={name}"], check=True)
    os.remove(tmp)
    print(f"{name}: {os.path.getsize(name)//1024} KB  {loc}")
