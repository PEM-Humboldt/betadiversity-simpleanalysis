## Establecer parámetros de sesión ####
### Cargar librerias/paquetes necesarios para el análisis ####

#### Verificar e instalar las librerías necesarias ####
packagesPrev <- installed.packages()[,"Package"]  
packagesNeed <- librerias <- c("dplyr", "ggdendro", "ggplot2", "ggspatial", "magrittr", "openxlsx", "pbapply", "plyr", "purrr", "sf", "this.path", "tibble", "vegan")  # Define los paquetes necesarios para ejecutar el codigo
new.packages <- packagesNeed[!(packagesNeed %in% packagesPrev)]  # Identifica los paquetes que no están instalados
if(length(new.packages)) {install.packages(new.packages, binary = TRUE)}  # Instala los paquetes necesarios que no están previamente instalados

#### Cargar librerías ####
lapply(packagesNeed, library, character.only = TRUE)  # Carga las librerías necesarias

## Establecer entorno de trabajo ####
dir_work <- this.path::this.path() %>% dirname()  # Establece el directorio de trabajo

### Definir entradas necesarias para la ejecución del análisis ####

# Definir la carpeta de entrada-insumos
input_folder<- file.path(dir_work, "input"); # "~/input"

# Crear carpeta output
output<- file.path(dir_work, "output"); dir.create(output)

#### Definir entradas necesarias para la ejecución del análisis ####
input <- list(
  dataset = file.path(input_folder, "dataset.csv"), # Ruta del archivo  que contiene datos de especies por sitio
  sp_col = "species", # Nombre de la columna en el 'dataset' que contiene los nombres de las especies
  site_col = "Vereda", # Nombre de la columna en el 'dataset' que hace referencia a los sitios
  beta_plot = "j", # Nombre del indice beta con el que generar diagramas exploratorios. Por defecto es j que corresponde a Jaccard. Mas info en https://rdrr.io/rforge/vegan/man/betadiver.html
  spatial_dataset = file.path(input_folder, "spatial_dataset.shp")  # Opcional. Si no se tiene, establecer como NULL. Ruta a un archivo espacial correspondiente al área de estudio. Debe tener una columna con el mismo nombre que 'site_col' para unir el archivo espacial con los resultados
)

## Organizacion de datos ####

### Generar matriz de sitios (filas) por especies (columnas) ####
original_dataset <- data.table::fread(input$dataset, header = T) %>% as.data.frame() # Lee el dataset original desde un archivo .csv
dataset_sp <- original_dataset %>% dplyr::filter(!is.na(  !!sym(input$sp_col)  ))  # Filtra los registros a nivel

data_matrix <- reshape2::dcast(dataset_sp, as.formula( paste(input$site_col, "~", input$sp_col) ), 
                               fun.aggregate = length, value.var = input$sp_col) %>% 
  tibble::column_to_rownames(input$site_col)  # Genera la matriz de sitios por especies


## Análisis de diversidad beta ####
# Lista de indices Beta a estimar (https://rdrr.io/rforge/vegan/man/betadiver.html)
index_list<- c("w", "-1", "c", "wb", "r", "I", "e", "t", "me", "j", "sor", "m", "-2", "co", "cc", "g", "-3", "l", "19", "hk", "rlb", "sim", "gl", "z")

beta_list<- pblapply(index_list,
                     function(i) {
                       
                       # beta entre sitios #
                       disim_analysis <- betadiver(data_matrix, method = i)  # Calcula la diversidad beta entre sitios utilizando el índice i
                       beta_matrix <- as.matrix(disim_analysis) # Convierte el análisis beta en una matriz
                       
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
print(beta_summ)

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



