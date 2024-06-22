---
title: "Flujo de trabajo – Análisis de diversidad Beta"
author: 
  - name: "Rincon-Parra VJ"
    email: "rincon-v@javeriana.edu.co"
  - name: "Gonzalo Cabezas Martin"
affiliation: "Instituto de Investigación de Recursos Biológicos Alexander von Humboldt - IAvH"
output: 
  #md_document:
  github_document:
    md_extension: +gfm_auto_identifiers
    preserve_yaml: true
    toc: true
    toc_depth: 6
---

Flujo de trabajo – Análisis de diversidad Beta
================
Este flujo de trabajo estima índices de diversidad beta para un área
general y entre los sitios que la integran. Consiste en la carga y
organización de datos para la estimación de estas métricas mediante la
libreria
[vegan](https://cran.r-project.org/web/packages/vegan/vegan.pdf) en R.
La diversidad beta evalúa la variación en la composición de especies
entre diferentes sitios dentro de un área, ofreciendo una perspectiva
sobre la heterogeneidad ecológica y las diferencias en las comunidades
biológicas a través del paisaje. Se estima comparando la composición de
especies entre sitios, tomando en cuenta tanto las especies únicas
presentes en un solo sitio como las especies compartidas entre múltiples
sitios.

## Tabla de contenido
- <a href="#organizar-directorio-de-trabajo"
  id="toc-organizar-directorio-de-trabajo">Organizar directorio de
  trabajo</a>
- <a href="#establecer-parámetros-de-sesión"
  id="toc-establecer-parámetros-de-sesión">Establecer parámetros de
  sesión</a>
  - <a href="#cargar-libreriaspaquetes-necesarios-para-el-análisis"
    id="toc-cargar-libreriaspaquetes-necesarios-para-el-análisis">Cargar
    librerias/paquetes necesarios para el análisis</a>
- <a href="#establecer-entorno-de-trabajo"
  id="toc-establecer-entorno-de-trabajo">Establecer entorno de trabajo</a>
  - <a href="#definir-inputs-y-direccion-output"
    id="toc-definir-inputs-y-direccion-output">Definir inputs y direccion
    output</a>
- <a href="#organizacion-de-datos"
  id="toc-organizacion-de-datos">Organizacion de datos</a>
- <a href="#análisis-de-diversidad-beta"
  id="toc-análisis-de-diversidad-beta">Análisis de diversidad beta</a>
- <a href="#figuras-de-diversidad-beta"
  id="toc-figuras-de-diversidad-beta">Figuras de diversidad beta</a>
  - <a href="#dendograma---similitud"
    id="toc-dendograma---similitud">Dendograma - Similitud</a>
  - <a href="#representación-espacial"
    id="toc-representación-espacial">Representación espacial</a>

## Organizar directorio de trabajo

<a id="ID_seccion1"></a>

Las entradas de ejemplo de este ejercicio están almacenadas en
[IAvH/Unidades
compartidas/BetaDiversityInput/input](https://drive.google.com/drive/folders/1DGOnUX2tLY5agzcAnOmLWUPN1qKCcOJ7?usp=drive_link).
Están organizadas de esta manera que facilita la ejecución del código:

    script
    │- Bdiversity.R
    │    
    └-input
    │ │
    │ │- dataset.csv
    │ │- spatial_dataset.shp
    │     
    └-output

## Establecer parámetros de sesión

### Cargar librerias/paquetes necesarios para el análisis

``` r
## Establecer parámetros de sesión ####
### Cargar librerias/paquetes necesarios para el análisis ####

#### Verificar e instalar las librerías necesarias ####
packagesPrev <- installed.packages()[,"Package"]  
packagesNeed <- c("magrittr", "this.path", "sf", "plyr", "dplyr", "vegan", "ggspatial")  # Define los paquetes necesarios para ejecutar el codigo
new.packages <- packagesNeed[!(packagesNeed %in% packagesPrev)]  # Identifica los paquetes que no están instalados
if(length(new.packages)) {install.packages(new.packages, binary = TRUE)}  # Instala los paquetes necesarios que no están previamente instalados

#### Cargar librerías ####
lapply(packagesNeed, library, character.only = TRUE)  # Carga las librerías necesarias
```

## Establecer entorno de trabajo

El flujo de trabajo está diseñado para establecer el entorno de trabajo
automáticamente a partir de la ubicación del código. Esto significa que
tomará como `dir_work` la carpeta raiz donde se almacena el código
“\~/scripts. De esta manera, se garantiza que la ejecución se realice
bajo la misma organización descrita en el paso de [Organizar directorio
de trabajo](#ID_seccion1).

``` r
## Establecer entorno de trabajo ####
dir_work <- this.path::this.path() %>% dirname()  # Establece el directorio de trabajo
```

### Definir inputs y direccion output

Dado que el código está configurado para definir las entradas desde la
carpeta input, en esta parte se debe definir una lista llamada input en
la que se especifica el nombre de cada una de las entradas necesarias
para su ejecución. Para este ejemplo, basta con usar file.path con
referencia a `input_folder` y el nombre del archivo para definir su ruta
y facilitar su carga posterior. No obstante, se podría definir cualquier
ruta de la máquina local como carpeta input donde se almacenen las
entradas, o hacer referencia a cada archivo directamente.

Asimismo, el código genera una carpeta output donde se almacenarán los
resultados del análisis. La ruta de esa carpeta se almacena por defecto
en el mismo directorio donde se encuentra el código.

``` r
### Definir entradas necesarias para la ejecución del análisis ####

# Definir la carpeta de entrada-insumos
input_folder<- file.path(dir_work, "input"); # "~/input"

# Crear carpeta output
output<- file.path(dir_work, "output"); dir.create(output)

#### Definir entradas necesarias para la ejecución del análisis ####
input <- list(
  dataset = file.path(input_folder, "Cruce_Llanos_1.csv"), # Ruta del archivo  que contiene datos de especies por sitio
  sp_col = "species", # Nombre de la columna en el 'dataset' que contiene los nombres de las especies
  site_col = "Vereda", # Nombre de la columna en el 'dataset' que hace referencia a los sitios
  beta_plot = "j", # Nombre del indice beta con el que generar diagramas exploratorios. Por defecto es j que corresponde a Jaccard. Mas info en https://rdrr.io/rforge/vegan/man/betadiver.html
  spatial_dataset = file.path(input_folder, "Veredas_Llanos_1.shp")  # Opcional. Si no se tiene, establecer como NULL. Ruta a un archivo espacial correspondiente al área de estudio. Debe tener una columna con el mismo nombre que 'site_col' para unir el archivo espacial con los resultados
)
```

La lista de entradas incluye la ruta completa al archivo que contiene
los datos de especies por sitio, el nombre de la columna en ´dataset´
que contiene los nombres de las especies, y el nombre de la columna en
´dataset´ que hace referencia a los sitios como unidad espacial de
analisis. Este dataset se utilizará para realizar los análisis de
diversidad beta, basándose en la definición de sp_col y
site_col. Además, se especifica un argumento opcional hacia la ruta de
un archivo espacial referente a las geometrias espaciales de los sitios
definidos. Este archivo se utilizará para espacializar y diagramar los
resultados del análisis y debe tener una columna con el mismo nombre que
site_col para permitir la unión con los resultados del análisis. Si no
se dispone del archivo shapefile, este parámetro puede establecerse como
NULL.

El código estima los 24 estimadores de diversidad beta detallados en el
argumento method de
[vegan::betadiver](https://rdrr.io/rforge/vegan/man/betadiver.html),
referentes a [Koleff et
al. (2003](https://besjournals.onlinelibrary.wiley.com/doi/10.1046/j.1365-2656.2003.00710.x)
para medir la diversidad beta con datos de presencia-ausencia. Sin
embargo, se limita a diagramar para exploración los resultados para una
sola opción definida por el usuario en la entrada beta_plot. Dichas
opciones son:
`"j", "w", "-1", "c", "wb", "r", "I", "e", "t", "me", "sor", "m", "-2", "co", "cc", "g", "-3", "l", "19", "hk", "rlb", "sim", "gl", "z"`.
Por defecto, se generan para `"j"`, que corresponde a diversidad beta
Jaccard. Dependiendo del método escogido, se genera un dendrograma que
muestra el agrupamiento jerárquico de los sitios basado en su similitud
o disimilitud según el índice beta utilizado. Si se utiliza un
spatial_dataset, también se puede representar espacialmente el índice.
Las opciones para beta_plot son las mismas que las especificadas en el
argumento method.

## Organizacion de datos

Los datos deben organizarse en una matriz de sitios (filas) por especies
(columnas). El código carga los datos y genera la matriz a partir de las
entradas site_col correspondiente a sitios como filas, y sp_col
correspondientes a especies como columnas.

``` r
### Generar matriz de sitios (filas) por especies (columnas) ####
original_dataset <- data.table::fread(input$dataset, header = T) %>% as.data.frame() # Lee el dataset original desde un archivo .csv
dataset_sp <- original_dataset %>% dplyr::filter(!is.na(  !!sym(input$sp_col)  ))  # Filtra los registros a nivel

data_matrix <- reshape2::dcast(dataset_sp, as.formula( paste(input$site_col, "~", input$sp_col) ), 
                               fun.aggregate = length, value.var = input$sp_col) %>% 
  tibble::column_to_rownames(input$site_col)  # Genera la matriz de sitios por especies
```

## Análisis de diversidad beta

``` r
## Análisis de diversidad beta ####
# Lista de indices Beta a estimar (https://rdrr.io/rforge/vegan/man/betadiver.html)
index_list<- c("w", "-1", "c", "wb", "r", "I", "e", "t", "me", "j", "sor", "m", "-2", "co", "cc", "g", "-3", "l", "19", "hk", "rlb", "sim", "gl", "z")

beta_list<- pblapply(index_list,
                     function(i) {
                       
                       # beta entre sitios #
                       disim_analysis <- betadiver(data_matrix, method = i)  # Calcula la diversidad beta entre sitios utilizando el índice i
                       beta_matrix <- as.matrix(disim_analysis)  # Convierte el análisis beta en una matriz
                       
                       # beta por sitio #
                       Bdiv_per_site <- rowMeans(beta_matrix)  # Calcula la diversidad beta por sitio como la media de la matriz
                       name_sites <- names(Bdiv_per_site) %>% as.character()  # Obtiene los nombres de los sitios
                       Bdiv_per_site_table <- as.data.frame(Bdiv_per_site) %>% tibble::rownames_to_column("site") %>% setNames(c("site", i)) # Crea una tabla con la diversidad beta por sitio
                       
                       list(Bdiv_per_site_table=Bdiv_per_site_table, beta_matrix= as.data.frame.matrix(beta_matrix) %>% tibble::rownames_to_column("site")  )
                     }) %>% setNames(index_list)

beta_matrix_list <- purrr::map(beta_list, "beta_matrix") # compilar matrices en una sola lista
beta_summ<- purrr::map(beta_list, "Bdiv_per_site_table") %>% plyr::join_all() # compilar indices alfa en una sola tabla

### Exportar tablas resultados beta ####
openxlsx::write.xlsx(beta_matrix_list, file.path(output, paste0("beta_matrix_list", ".xlsx")))
openxlsx::write.xlsx(beta_summ, file.path(output, paste0("beta_summ", ".xlsx")))

### Ver tabla indices de diversidad beta ####
print(head(beta_summ))
```

|                        |         w |        -1 |         c |       wb |         r |         I |         e |         t |        me |         j |       sor |        m |        -2 |        co |        cc |         g |        -3 |         l |        19 |        hk |       rlb |       sim |        gl |         z |
|:-----------------------|----------:|----------:|----------:|---------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|---------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Aeropuerto La Bastilla | 0.9463019 | 0.9463019 |  74.57407 | 149.1481 | 0.3360828 | 0.3772688 | 0.4802798 | 0.9463019 | 0.9463019 | 0.0214074 | 0.0413525 | 152.2348 | 0.2126985 | 0.8835461 | 0.9662469 | 0.9662469 | 0.1528801 |  74.57407 | 0.2271623 | 0.9463019 | 0.1762689 | 0.8044778 | 1.2922907 | 0.9573051 |
| Algarrobo              | 0.7251360 | 0.7251360 | 109.88889 | 219.7778 | 0.2641368 | 0.3422801 | 0.4184408 | 0.7251360 | 0.7251360 | 0.1606498 | 0.2625183 | 256.8391 | 0.2523132 | 0.6574878 | 0.8270045 | 0.8270045 | 0.1827861 | 109.88889 | 0.1972034 | 0.7251360 | 0.2665227 | 0.5388012 | 0.8384014 | 0.7786310 |
| Alianza                | 0.7144399 | 0.7144399 |  79.70370 | 159.4074 | 0.2555469 | 0.3498796 | 0.4275176 | 0.7144399 | 0.7144399 | 0.1694952 | 0.2732144 | 186.6540 | 0.2109754 | 0.6509950 | 0.8181591 | 0.8181591 | 0.1624409 |  79.70370 | 0.1928606 | 0.7144399 | 0.3730770 | 0.5240721 | 0.8782919 | 0.7687300 |
| Banquetas              | 0.8219202 | 0.8219202 | 144.83951 | 289.6790 | 0.3630813 | 0.3940044 | 0.5007330 | 0.8219202 | 0.8219202 | 0.0937130 | 0.1657341 | 318.9779 | 0.3206583 | 0.7711017 | 0.8939413 | 0.8939413 | 0.2158049 | 144.83951 | 0.2459493 | 0.8219202 | 0.1601402 | 0.6870577 | 0.8716456 | 0.8606208 |
| Barbasco               | 0.7249301 | 0.7249301 |  80.68519 | 161.3704 | 0.2666244 | 0.3569803 | 0.4378799 | 0.7249301 | 0.7249301 | 0.1615558 | 0.2627242 | 187.8260 | 0.2185498 | 0.6615217 | 0.8260985 | 0.8260985 | 0.1670231 |  80.68519 | 0.1995050 | 0.7249301 | 0.3575127 | 0.5366837 | 0.8798107 | 0.7780095 |
| Belgrado               | 0.6871911 | 0.6871911 | 106.96296 | 213.9259 | 0.2219763 | 0.3117846 | 0.3764101 | 0.6871911 | 0.6871911 | 0.1930356 | 0.3004632 | 254.1603 | 0.2211644 | 0.6121804 | 0.7946188 | 0.7946188 | 0.1615430 | 106.96296 | 0.1679522 | 0.6871911 | 0.3046610 | 0.4795690 | 0.8439009 | 0.7429176 |

Los resultados son una tabla de datos donde la primera columna
representa el sitio analizado, y las columnas restantes contienen las
estimaciones de diversidad beta media con todos los indicadores
descritos para cada uno de los sitios. Estos resultados se almacenan
como `beta_results.xlsx` en la carpeta de salida definida. De la misma
manera, las matrices de similitud de cada índice se exportaron en un
archivo `beta_matrix_list.xlsx`, en el que cada hoja corresponde a cada
uno de los índices.

## Figuras de diversidad beta

Se generaron figuras para análisis exploratorios de los resultados del
`beta_plot` definido. Primero, se creó un dendrograma de similitud
basado en el índice beta seleccionado. Segundo, cuando se dispuso de un
\``spatial_dataset`, se realizó una representación espacial de los
resultados.

### Dendograma - Similitud

``` r
## Figuras de diversidad beta ####

### Definir datos indice a diagramar ####
beta_index_data<- beta_list[[input$beta_plot]]

### Dendograma - Similitud ####
disimhclust <- hclust(as.dist(beta_index_data$beta_matrix %>% dplyr::select(-site) ))  # Realiza un análisis de conglomerados jerárquicos en la matriz de disimilaridad
disimdend <- as.dendrogram(disimhclust)  # Convierte el análisis de conglomerados en un dendrograma
disimdend_data <- ggdendro::dendro_data(disimdend)  # Extrae los datos del dendrograma para visualización

var_table <- with(disimdend_data$labels, data.frame(y_center = x, y_min = x - 0.5, y_max = x + 0.5, Variable = gsub("\n|\r", "", as.character(label)), height = 1))  # Prepara la tabla de variables para la visualización del dendrograma
is.even <- function(x) { x %% 2 == 0 }  # Función para verificar si un número es par
var_table$col <- rep_len(c("#EBEBEB", "white"), length.out = length(var_table$Variable)) %>% {if (is.even(length(.))) {rev(.)} else {.}}  # Asigna colores alternativos a las filas del dendrograma
segment_data <- with(ggdendro::segment(disimdend_data), data.frame(x = y, y = x, xend = yend, yend = xend, disim = yend))  # Prepara los datos de los segmentos del dendrograma para la visualización

# Generar la figura del dendograma
dendroBeta <- ggplot2::ggplot() +
  ggplot2::annotate("rect", xmin = -0.05, xmax = 1.04, fill = var_table$col, ymin = var_table$y_min, ymax = var_table$y_max, alpha = 0.75) +  # Añade los rectángulos de fondo alternativos
  ggplot2::geom_segment(data = segment_data, aes(x = x, y = y, xend = xend, yend = yend, label = disim), size = 0.3) +  # Añade los segmentos del dendrograma
  ggplot2::scale_y_continuous(breaks = var_table$y_center, labels = var_table$Variable) +  # Escala y ajusta el eje y
  ggplot2::coord_cartesian(expand = FALSE) +  # Ajusta la coordenada del gráfico
  ggplot2::labs(x = input$beta_plot, y = "Site") +  # Etiqueta los ejes
  ggplot2::theme(plot.margin = ggplot2::margin(t = 0, r = 0, b = 0, l = 0),
                 panel.grid.major = ggplot2::element_line(color = "gray"),
                 axis.ticks.length = ggplot2::unit(0.3, "mm"),
                 text = ggplot2::element_text(size = 8))  # Ajusta la temática del gráfico

#### Exportar dendograma beta ####
ggplot2::ggsave(file.path(output, paste0(input$beta_plot, "_dendroBeta", ".jpeg")), dendroBeta )

#### Ver tabla indices de diversidad beta ####
print(dendroBeta)
```

![](README_figures/j_dendroBeta.jpeg)

El dendrograma resultante muestra la similitud entre sitios basada en la
disimilaridad calculada a partir de la diversidad beta, lo cual
cuantifica las diferencias entre sitios en términos de composición de
especies. Como resultado, el dendrograma organiza los sitios en una
estructura jerárquica donde las ramas indican la similitud entre grupos
de sitios, proporcionando una representación clara de cuáles son más
parecidos entre ellos.

### Representación espacial

Cuando se define un `spatial_dataset` como entrada, se genera un mapa
que representa espacialmente la diversidad beta por sitio. Este
`spatial_dataset` debe tener una columna con el mismo atributo espacial
que el dataset, lo cual permite hacer un join entre los resultados para
crear un diagrama de la unidad espacial que refleje el indicador beta
estimado para esa unidad.

``` r
### Representación espacial ####
if(!is.null(input$spatial_dataset)){

#### Cargar archivo espacial ####
spatial_data <- sf::st_read(input$spatial_dataset)   # Lee los datos espaciales desde el archivo vectorial definido

#### Espacializar indice ####
# Agregar el indice beta estimado al archivo espacial
spatial_data_index<- dplyr::select(beta_summ, c("site", input$beta_plot)) %>% 
  setNames(c(input$site_col, input$beta_plot)) %>% list(as.data.frame(spatial_data)) %>% plyr::join_all() %>% 
  dplyr::filter(!is.na(!!sym(input$beta_plot))) %>% sf::st_as_sf()
  
#### Plot espacial Beta ####
beta_map<-   ggplot2::ggplot() +
  ggspatial::annotation_map_tile(type = "cartolight") +
  ggplot2::geom_sf(data= spatial_data_index, col= NA, aes(fill= !!sym(input$beta_plot)), alpha= 0.75 )+
  ggplot2::scale_fill_distiller(palette = "BuGn", name = "Beta") +
  ggplot2::theme(text = ggplot2::element_text(size = 8))
  
#### Exportar mapa beta ####
ggplot2::ggsave(file.path(output, paste0(input$beta_plot, "_beta_map", ".jpeg")), beta_map )

#### Ver mapa beta ####
print(beta_map)}
```

![](README_figures/j_beta_map.jpeg)
