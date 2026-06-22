import numpy as np
from datetime import datetime


# =========================
# MAIN READER (2025 FORMAT)
# =========================
def aml_data_read_2025(fname):

    H = {}
    V = {}
    D = []

    with open(fname, 'r') as fid:
        lines = fid.readlines()

    i = 0
    
    while i < len(lines):
        line = lines[i].strip()
        
        if line == '[Header]':
            H, i = read_header(lines, i + 1)
        
        elif line == '[MeasurementMetadata]':
            V, i = read_metadata(lines, i + 1)
        
        elif line == '[MeasurementData]':
            D, i = read_data(lines, i + 1, V)
        
        else:
            i += 1

    return H, V, D


# =========================
# HEADER
# =========================
def read_header(lines, i):
    H = {}

    while i < len(lines):
        line = lines[i].strip()
        if line == "":
            break
        
        if '=' in line:
            key, val = line.split('=', 1)
            H[key.strip()] = val.strip()
        
        i += 1

    return H, i


# =========================
# METADATA (2025 FIX)
# =========================
def read_metadata(lines, i):

    while i < len(lines):
        line = lines[i].strip()
        if line == "":
            break

        var = line.replace('=', ',').split(',')
        i += 1

        unit = lines[i].strip().replace('=', ',').split(',')
        i += 1

    # ✅ KEY FIX (2025 has more variables)
    V = {
        "var": var[1:24],
        "unit": unit[1:24]
    }

    return V, i


# =========================
# DATA (2025 FIX)
# =========================
def read_data(lines, i, V):

    dat = []

    while i < len(lines):
        line = lines[i].strip()

        if line == "":
            break
        
        dat.append(line.split(','))
        i += 1

    dat = np.array(dat)

    D = []

    # -------------------------
    # TIME (safe parsing)
    # -------------------------
    time_list = []

    for row in dat:
        try:
            dt = datetime.strptime(row[0] + " " + row[1], "%Y-%m-%d %H:%M:%S.%f")
        except:
            try:
                dt = datetime.strptime(row[0] + " " + row[1], "%Y-%m-%d %H:%M:%S")
            except:
                dt = None
        time_list.append(dt)

    D.append({
        "name": "Time",
        "units": "datetime",
        "dat": np.array(time_list)
    })

    # -------------------------
    # DATA COLUMNS
    # -------------------------
    n_cols = min(len(V["var"]), dat.shape[1])

    for col in range(2, n_cols):

        try:
            values = np.array([float(x) for x in dat[:, col]])
        except:
            values = np.full(len(dat), np.nan)

        name = V["var"][col] if col < len(V["var"]) else f"Var_{col}"
        units = V["unit"][col] if col < len(V["unit"]) else ""

        D.append({
            "name": name,
            "units": units,
            "dat": values
        })

    return D, i


# =========================
# REMOVE NAN (UNCHANGED ✅)
# =========================
def aml_remove_nan(A, idepth):

    ii = np.isfinite(A[idepth]['dat'])

    D = []
    for d in A:
        D.append({
            'name': d['name'],
            'units': d['units'],
            'dat': d['dat'][ii]
        })

    return D


# =========================
# OXYGEN CORRECTION (UNCHANGED ✅)
# =========================
def aml_oxygen_correction(D, idox, itempDO, ipress, isalt, idens):

    cP = 4.5e-3

    P_MPa = D[ipress]['dat'] * 0.01
    temp = D[itempDO]['dat']
    DO_raw = D[idox]['dat']
    sal = D[isalt]['dat']

    Ts = np.log((298.15 - temp) / (273.15 + temp))

    DOpc = DO_raw * (1 + cP * P_MPa)

    B0 = -0.00701577
    B1 = -0.00770028
    B2 = -0.0113864
    B3 = -0.00951519
    C0 = -2.75915e-7

    DO = DOpc * np.exp(
        sal * (B0 + B1 * Ts + B2 * Ts**2 + B3 * Ts**3)
        + C0 * sal**2
    )

    D[idox]['datc'] = DO_raw.copy()
    D[idox]['dat'] = DO

    return D
