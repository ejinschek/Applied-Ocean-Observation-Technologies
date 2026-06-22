#aml_data_read

import numpy as np
from datetime import datetime, timedelta

def aml_data_read(fname):
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


def read_metadata(lines, i):
    while i < len(lines):
        line = lines[i].strip()
        if line == "":
            break

        var = line.replace('=', ',').split(',')

        i += 1
        unit_line = lines[i].strip()
        unit = unit_line.replace('=', ',').split(',')

        i += 1

    V = {
        "var": var[1:22],
        "unit": unit[1:22]
    }

    return V, i


def read_data(lines, i, V):
    dat = []

    while i < len(lines):
        line = lines[i].strip()
        if line == "":
            break

        parts = line.split(',')
        dat.append(parts)

        i += 1

    dat = np.array(dat)

    D = []

    date_col = dat[:, 0]
    time_col = dat[:, 1]

    matlab_time = []
    for d, t in zip(date_col, time_col):
        dt = datetime.strptime(d + " " + t, "%Y-%m-%d %H:%M:%S.%f")
        matlab_time.append(dt)

    D.append({
        "name": "Time",
        "units": "Days since 0000",
        "dat": np.array(matlab_time)
    })

    # make sure we don't go out of bounds
    n_cols = dat.shape[1]

    for col in range(2, n_cols):
    
        values = np.array([float(x) for x in dat[:, col]])
        
        # safe naming (important fix ✅)
        if col < len(V["var"]):
            name = V["var"][col]
        else:
            name = f"Var_{col}"

        if col < len(V["unit"]):
            units = V["unit"][col]
        else:
            units = ""

        D.append({
            "name": name,
            "units": units,
            "dat": values
        })


    return D, i

#aml_remove_nan

import numpy as np

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

#aml_oxygen_correction

import numpy as np

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

