%% PASO 1 - Leer el archivo ODV del UVP6
clear; clc; close all;

% Ruta del archivo (ajusta el nombre si es distinto)
ruta = 'C:\Programing\AppliedOcean\UVP6\uvp6_sn000251hf_20260613_havfisken\results\';
archivo = [ruta 'uvp6_sn000251hf_20260613_havfisken_odv.txt'];

% Configuramos cómo leer el archivo: separado por ';' y con 7 líneas de
% cabecera de comentarios antes de los nombres de columna
opts = detectImportOptions(archivo, 'Delimiter', ';', 'NumHeaderLines', 6);

% Leemos la tabla
data = readtable(archivo, opts);

% Vemos cuántas filas y columnas tiene, y los primeros nombres de columna
disp('Tamaño de la tabla (filas x columnas):')
disp(size(data))

disp('Primeras 15 columnas:')
disp(data.Properties.VariableNames(1:15))


%% PASO 2 - Usar nombres de columna originales y rellenar estaciones

% Volvemos a leer pero conservando los nombres originales de columna
opts.VariableNamingRule = 'preserve';
data = readtable(archivo, opts);

% Mostramos los nombres reales (originales) de columna
disp('Nombres de columna originales:')
disp(data.Properties.VariableNames(1:15)')

% Las columnas de "Station", fecha y coordenadas solo tienen valor en la
% primera fila de cada estación. Rellenamos hacia abajo:
data.("Station:METAVAR:TEXT:20") = fillmissing(data.("Station:METAVAR:TEXT:20"), 'previous');
data.("Latitude [degrees_north]:METAVAR:DOUBLE") = fillmissing(data.("Latitude [degrees_north]:METAVAR:DOUBLE"), 'previous');
data.("Longitude [degrees_east]:METAVAR:DOUBLE") = fillmissing(data.("Longitude [degrees_east]:METAVAR:DOUBLE"), 'previous');

% Vemos cómo queda
disp('Estaciones encontradas:')
disp(unique(data.("Station:METAVAR:TEXT:20")))


%% PASO 3 - Renombrar columnas clave para que sea más fácil trabajar

data = renamevars(data, ...
    {'Station:METAVAR:TEXT:20', ...
     'Latitude [degrees_north]:METAVAR:DOUBLE', ...
     'Longitude [degrees_east]:METAVAR:DOUBLE', ...
     'Depth [m]:PRIMARYVAR:DOUBLE', ...
     'Sampled volume [L]'}, ...
    {'Station', 'Lat', 'Lon', 'Depth', 'Volume'});

% Comprobamos que el cambio ha funcionado
disp('Nombres de columna ahora:')
disp(data.Properties.VariableNames(1:15)')


%% PASO 4 - Identificar columnas de abundancia de partículas (LPM)

% Buscamos todas las columnas que empiezan por "LPM (" y que NO dicen "biovolume"
nombres_col = data.Properties.VariableNames;

es_LPM_abundancia = startsWith(nombres_col, 'LPM (') & ~contains(nombres_col, 'biovolume');

columnas_LPM = nombres_col(es_LPM_abundancia);

disp('Número de clases de tamaño LPM encontradas:')
disp(length(columnas_LPM))

disp('Primeras y últimas clases de tamaño:')
disp(columnas_LPM(1:3)')
disp(columnas_LPM(end-2:end)')

%% PASO 5 - Calcular abundancia total de "zooplancton" (>256 µm) [CORREGIDO]

zoo_cols = {};
for i = 1:length(columnas_LPM)
    nombre = columnas_LPM{i};
    
    % Extraemos el primer número del rango, ignorando símbolos como '>' o '('
    numero = regexp(nombre, '([\d.]+)', 'tokens');
    valor = str2double(numero{1}{1});
    
    % Si la unidad es mm, lo convertimos a µm (1 mm = 1000 µm)
    if contains(nombre, 'mm')
        valor = valor * 1000;
    end
    
    % Si es mayor o igual a 256 µm, lo guardamos como zooplancton
    if valor >= 256
        zoo_cols{end+1} = nombre;
    end
end

disp('Columnas consideradas zooplancton (>=256 µm):')
disp(zoo_cols')

% Sumamos la abundancia de todas esas columnas para cada fila (profundidad)
data.Zoo_abundance = sum(data{:, zoo_cols}, 2);

disp('Primeras filas de Station, Depth y Zoo_abundance:')
disp(data(1:10, {'Station', 'Depth', 'Zoo_abundance'}))


%% PASO 6 - Gráfica de abundancia de zooplancton vs profundidad (una estación)

% Elegimos una estación para probar
estacion_prueba = 'havfisken_484';

% Filtramos solo las filas de esa estación
filas = strcmp(data.Station, estacion_prueba);
profundidad = data.Depth(filas);
zoo = data.Zoo_abundance(filas);

% Hacemos la gráfica
figure;
plot(zoo, -profundidad, '-o', 'LineWidth', 1.5, 'MarkerFaceColor', 'b');
xlabel('Abundancia de zooplancton (partículas/L, >256 µm)');
ylabel('Profundidad (m)');
title(['Perfil de zooplancton - ' estacion_prueba]);
grid on;



%% PASO 7 - Gráfica de TODAS las estaciones juntas

estaciones_unicas = unique(data.Station);

figure;
hold on;
colores = lines(length(estaciones_unicas)); % genera un color distinto por estación

for i = 1:length(estaciones_unicas)
    filas = strcmp(data.Station, estaciones_unicas{i});
    profundidad = data.Depth(filas);
    zoo = data.Zoo_abundance(filas);
    
    plot(zoo, -profundidad, '-o', 'Color', colores(i,:), 'LineWidth', 1.2);
end

xlabel('Abundancia de zooplancton (partículas/L, >256 µm)');
ylabel('Profundidad (m)');
title('Perfiles de zooplancton - todas las estaciones');
legend(estaciones_unicas, 'Location', 'best', 'Interpreter', 'none');
grid on;
hold off;

%% PASO 8 - Calcular abundancia de partículas pequeñas (1-256 µm)

small_cols = {};
for i = 1:length(columnas_LPM)
    nombre = columnas_LPM{i};
    
    numero = regexp(nombre, '([\d.]+)', 'tokens');
    valor = str2double(numero{1}{1});
    
    if contains(nombre, 'mm')
        valor = valor * 1000;
    end
    
    % Esta vez nos quedamos con tamaños MENORES a 256 µm
    if valor < 256
        small_cols{end+1} = nombre;
    end
end

disp('Número de columnas de partículas pequeñas (<256 µm):')
disp(length(small_cols))

% Sumamos la abundancia de todas esas columnas para cada fila (profundidad)
data.Small_abundance = sum(data{:, small_cols}, 2);

disp('Primeras filas de Station, Depth y Small_abundance:')
disp(data(1:10, {'Station', 'Depth', 'Small_abundance'}))

%% PASO 9 - Gráfica de partículas pequeñas, todas las estaciones (gráfico separado)

figure;
hold on;
colores = lines(length(estaciones_unicas));

for i = 1:length(estaciones_unicas)
    filas = strcmp(data.Station, estaciones_unicas{i});
    profundidad = data.Depth(filas);
    small = data.Small_abundance(filas);
    
    plot(small, -profundidad, '-o', 'Color', colores(i,:), 'LineWidth', 1.2);
end

xlabel('Abundancia de partículas pequeñas (partículas/L, <256 µm)');
ylabel('Profundidad (m)');
title('Perfiles de partículas pequeñas - todas las estaciones');
legend(estaciones_unicas, 'Location', 'best', 'Interpreter', 'none');
grid on;
hold off;

