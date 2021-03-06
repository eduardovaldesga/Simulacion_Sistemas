##############################################################################
###                          Practica 4 Voronoi                             ##
###                                                                         ##
###                     28/08/2017                                          ##
###                                                                         ##
##############################################################################
#file.remove(list.files(pattern=".png")) 

library(RColorBrewer) ## Libreria de colores 
library(ggplot2)
suppressMessages(library(doParallel))
library(stats)
library(moments)
library(nortest)
library(e1071)
library(pryr)



rm(list=ls())

#n <-  40  #### tama�o de la cuadricula
nt <- c(40,50,60,70,80,90)


#k <- 12   #### Cantidad de semillas 
kt <-c(12,12+12*0.25,12+12*0.5,12+12*0.75, 12*2,12*3,12*4)


vp <- data.frame(numeric(), numeric()) # posiciones de posibles vecinos
for (dx in -1:1) {
  for (dy in -1:1) {
    if (dx != 0 | dy != 0) { # descartar la posicion misma
      vp <- rbind(vp, c(dx, dy))
    }
  }
}
names(vp) <- c("dx", "dy")
vc <- dim(vp)[1]



inicio <- function() {
  direccion <- sample(1:4, 1)
  xg <- NULL
  yg <- NULL
  if (direccion == 1) { # vertical
    xg <- 1
    yg <- sample(1:n, 1)
  } else if (direccion == 2) { # horiz izr -> der
    xg <- sample(1:n, 1)
    yg <- 1
  } else if (direccion == 3) { # horiz der -> izq
    xg <- n
    yg <- sample(1:n, 1)
  } else { # vertical al reves
    xg <- sample(1:n, 1)
    yg <- n
  }
  return(c(xg, yg))
}


celda <-  function(pos) {
  fila <- floor((pos - 1) / n) + 1
  columna <- ((pos - 1) %% n) + 1
  if (zona[fila, columna] > 0) { # es una semilla
    return(zona[fila, columna])
  } else {
    cercano <- NULL # sin valor por el momento
    menor <- n * sqrt(2) # mayor posible para comenzar la busqueda
    for (semilla in 1:k) {
      dx <- columna - x[semilla]
      dy <- fila - y[semilla]
      dist <- sqrt(dx^2 + dy^2)
      if (dist < menor) {
        cercano <- semilla
        menor <- dist
      }
    }
    return(cercano)
  }
}

setwd("C:/Users/Z230/Dropbox/PISIS/PhD/Simulacion_Sistemas/Practica_4/Graficas") 

propaga <- function(replica) {
  # probabilidad de propagacion interna
  prob <- 1
  dificil <- 0.99
  grieta <- voronoi # marcamos la grieta en una copia
  i <- inicio() # posicion inicial al azar
  xg <- i[1]
  yg <- i[2]
  largo <- 0
  while (TRUE) { # hasta que la propagacion termine
    grieta[yg, xg] <- 0 # usamos el cero para marcar la grieta
    largo <-  largo + 1
    frontera <- numeric()
    interior <- numeric()
    for (v in 1:vc) {
      vecino <- vp[v,]
      xs <- xg + vecino$dx # columna del vecino potencial
      ys <- yg + vecino$dy # fila del vecino potencial
      if (xs > 0 & xs <= n & ys > 0 & ys <= n) { # no sale de la zona
        if (grieta[ys, xs] > 0) { # aun no hay grieta ahi
          if (voronoi[yg, xg] == voronoi[ys, xs]) {
            interior <- c(interior, v)
          } else { # frontera
            frontera <- c(frontera, v)
          }
        }
      }
    }
    elegido <- 0
    if (length(frontera) > 0) { # siempre tomamos frontera cuando haya
      if (length(frontera) > 1) {
        elegido <- sample(frontera, 1)
      } else {
        elegido <- frontera # sample sirve con un solo elemento
      }
      prob <- 1 # estamos nuevamente en la frontera
    } else if (length(interior) > 0) { # no hubo frontera para propagar
      if (runif(1) < prob) { # intentamos en el interior
        if (length(interior) > 1) {
          elegido <- sample(interior, 1)
        } else {
          elegido <- interior
        }
        prob <- dificil * prob # mas dificil a la siguiente
      }
    }
    if (elegido > 0) { # si se va a propagar
      vecino <- vp[elegido,]
      xg <- xg + vecino$dx
      yg <- yg + vecino$dy
    } else {
      break # ya no se propaga
    }
  }
  if (largo >= limite) {
    png(paste("p4g_", replica, ".png", sep=""))
    par(mar = c(0,0,0,0))
    image(rotate(grieta), col=rainbow(k+1), xaxt='n', yaxt='n')
    graphics.off()
  }
  return(largo)
}


suppressMessages(library(doParallel))
registerDoParallel(makeCluster(detectCores() - 1))



datos<-data.frame()
datos2<-data.frame()

for ( k in kt){
  for ( n in nt){ 
    
    zona <- matrix(rep(0, n * n), nrow = n, ncol = n)
    
    x <- rep(0, k) # ocupamos almacenar las coordenadas x de las semillas
    y <- rep(0, k) # igual como las coordenadas y de las semillas
    
    for (semilla in 1:k) {
      while (TRUE) { # hasta que hallamos una posicion vacia para la semilla
        fila <- sample(1:n, 1)    ##### primer reto 
        columna <- sample(1:n, 1)  ###
        if (zona[fila, columna] == 0) {
          zona[fila, columna] = semilla
          x[semilla] <- columna
          y[semilla] <- fila
          break
        }
      }
      
    }
    celdas <- foreach(p = 1:(n * n), .combine=c) %dopar% celda(p)
    stopImplicitCluster()
    voronoi <- matrix(celdas, nrow = n, ncol = n, byrow=TRUE)
    rotate <- function(x) t(apply(x, 2, rev))
    #png("p4s.png")
    #par(mar = c(0,0,0,0))
    #image(rotate(zona), col=rainbow(k+1), xaxt='n', yaxt='n')
    #graphics.off()
    #png("p4c.png")
    #par(mar = c(0,0,0,0))
    #image(rotate(voronoi), col=rainbow(k+1), xaxt='n', yaxt='n')
    #graphics.off()
    
    limite <- n # grietas de que largo minimo queremos graficar
    #for (r in 1:10) { # para pruebas sin paralelismo
    largos <- foreach(r = 1:200, .combine=c) %dopar% propaga(r)
    for ( q in 1:200){
      datos<-rbind(datos,c(n,k,largos[q]))
    }
    #datos2<-rbind(datos,c(n,k,t(largos)))
  }
}

stopImplicitCluster()

setwd("C:/Users/Z230/Dropbox/PISIS/PhD/Simulacion_Sistemas/Practica_4/Codigo") 
names(datos)<-c("n","k","Largos")
write.csv (datos, file="datos.csv")




setwd("C:/Users/Z230/Dropbox/PISIS/PhD/Simulacion_Sistemas/Practica_4/Graficas") 
png("P4Divididas.png")
par(mfcol=c(1,2)) 
boxplot(Largos~n, data=datos,ylab="Longitud", xlab="Tama�o cuadridula",  main="n", col=topo.colors(length(nt)))
boxplot(Largos~k, data=datos, main="k",ylab="Longitud", xlab="Cantidad de semillas", col=cm.colors(length(kt))[length(kt):1 ]  )
dev.off()






### Estadistica

setwd("C:/Users/Z230/Dropbox/PISIS/PhD/Simulacion_Sistemas/Practica_4/Pruebas_Estadisticas") 
ac<-lm(Largos~k+n, data = datos)
png("P4_histograma.png")
hist(resid(ac), freq = F, main="Histograma",xlab=" ", ylab=" ", ylim=c(0,0.03))
lines(density(resid(ac)), col=3  )
c<-ad.test(resid(ac))[2]
text( mean(density(resid(ac))$x) ,max(density(resid(ac))$y),"AD valor p:" )
text( mean(density(resid(ac))$x)+(mean(density(resid(ac))$x))/2.7 ,max(density(resid(ac))$y),c )
dev.off()


sink("lm.txt")
print(summary(ac))
sink() 



Valor_p<-apply(datos[,1:2],2, function(x) kruskal.test(datos[,3]~x)$p.value)
Estadistico<-apply(datos[,1:2],2, function(x) kruskal.test(datos[,3]~x)$statistic )
ar<-c(Estadistico,Valor_p)

az<-matrix(ar,ncol=2,nrow = 2)
colnames(az)<-c("Kruskal","Valor p")
row.names(az)<-c("n","k")
write.csv (az, file="P4_Kruskal.csv")








setwd("C:/Users/Z230/Dropbox/PISIS/PhD/Simulacion_Sistemas/Practica_4/Graficas") 
### Defino mi paleta de colores
tq<-as.numeric(names(table(datos[,1])))
colores<-brewer.pal(n = length(tq), name = 'Accent')


datos$n<-as.factor(datos$n)
datos$k<-as.factor(datos$k)
datos$Largos<-as.numeric(datos$Largos)

w24<-paste("P4_n",  ".png", sep="")
png(w24)
ggplot(datos,aes(x=n, y=Largos, fill=n) )+geom_violin(trim=FALSE)+
scale_fill_brewer(palette = "RdBu")+ theme_minimal()+ stat_summary(fun.y=mean, geom="point",color="black",  size=2)
dev.off()




w25<-paste("P4_k",  ".png", sep="")
png(w25)
ggplot(datos,aes(x=k, y=Largos, fill=k) )+geom_violin()+geom_violin(trim=FALSE)+
  scale_fill_brewer(palette = "Dark2")+ theme_minimal()+ stat_summary(fun.y=mean, geom="point",color="black",  size=2)
dev.off()


#w21<-paste("P4_Segmentado",  ".pdf", sep="")
#pdf(file = w21, bg = "transparent")
png("P4_Segmentado.png")
ggplot(datos,  aes(x=n, y=Largos)) +
  geom_boxplot(aes(fill=k) )+theme_bw()+ ylab("Largo")+ xlab("Tama�o de cuadricula")+
  facet_wrap( ~k , scales="free")+ ggtitle("Segmentados")+theme_bw()+
  theme(plot.title = element_text(size = 14, family = "Tahoma", face = "bold"),
        text = element_text(size = 12, family = "Tahoma"),
        axis.title = element_text(face="bold"),
        axis.text.x=element_text(size = 11)) +ylim(0,max(datos$Largos))+
  scale_fill_brewer(palette = "Accent")

graphics.off()
dev.off()






png("P4_Todos.png")
ggplot(datos, aes(x=n, y=Largos, fill=k)) +geom_violin()+
  theme_bw()+ ylab("Largo")+ xlab("Tama�o cuadricula")+ ggtitle("Todos")+
  scale_fill_brewer(palette = "Accent")
dev.off()
graphics.off()


#file.remove(list.files(pattern=".png")) 



#frames=lapply(0:284,function(x) image_read(paste("P4R2_", repetir, ".png",sep="")))
#animation <- image_animate(image_join(frames))
#print(animation)
#w3<-paste("P4R2_voronoi",  ".gif"  )
#image_write(animation, w3)
#sapply(0:200,function(x) file.remove(paste("p4g_",x,".png",sep="")))
