// Ejecutar con tests/pizarra/probar.sh [captura.png]
#define main main_pizarra
#include "../../hypr/.config/hypr/pizarra/pizarra.cpp"
#undef main
#include <QtTest>
#include <stdexcept>

static void comprobar(bool ok,const char *mensaje){if(!ok)throw std::runtime_error(mensaje);}
static void escribir(const QString &p,const QJsonObject &j){
    QFile f(p);comprobar(f.open(QIODevice::WriteOnly),"crear datos de prueba");f.write(QJsonDocument(j).toJson());
}
int main(int argc,char **argv){
    QTemporaryDir temp;
    qputenv("XDG_STATE_HOME",temp.path().toUtf8());qputenv("QT_QPA_PLATFORM","offscreen");
    QApplication app(argc,argv);app.setStyle("Fusion");
    const QString captura=app.arguments().value(1);
    QDir().mkpath(temp.path()+"/mesa-trabajo");
    escribir(temp.path()+"/mesa-trabajo/proyectos.json",{{"proyectos",QJsonArray{Json{{"id","redes"},{"nombre","Laboratorio de redes"}}}}});
    const QString pdf=temp.path()+"/Guía de redes.pdf";
    {
        QPdfWriter documento(pdf);documento.setResolution(96);QPainter p(&documento);
        p.setPen(QColor("#273547"));p.setFont(letra(32,true));p.drawText(48,100,"Laboratorio de redes");
        documento.newPage();p.setFont(letra(34,true));p.drawText(48,90,"Práctica 04");
        p.setFont(letra(23));p.drawText(48,147,"Comunicación entre VLAN");
        p.setFont(letra(18));p.drawText(48,222,"01    Configura las interfaces");p.drawText(48,270,"02    Comprueba el enlace troncal");
        p.drawLine(48,310,620,310);p.drawText(48,370,"03    Verifica la puerta de enlace");
    }
    QImage diagrama(600,380,QImage::Format_RGB32);diagrama.fill(QColor("#18292c"));
    {QPainter p(&diagrama);p.setRenderHint(QPainter::Antialiasing);
     for(auto pt:{QPoint(100,190),QPoint(298,92),QPoint(485,205)}){p.setPen(QPen(QColor("#7aaca1"),4));p.drawLine(pt,QPoint(298,239));}
     for(auto pt:{QPoint(100,190),QPoint(298,92),QPoint(485,205),QPoint(298,239)}){
         p.setBrush(QColor("#284447"));p.setPen(QPen(QColor("#a5dacc"),3));p.drawRoundedRect(QRect(pt-QPoint(35,20),QSize(70,40)),8,8);
     }
     p.setFont(letra(20,true));p.drawText(24,350,"Topología del laboratorio");}
    Pizarra w(QCoreApplication::applicationDirPath());w.resize(1160,740);w.show();app.processEvents();
    comprobar(w.iniciar("redes"),"abrir proyecto");auto *v=dynamic_cast<Lienzo*>(w.findChild<QGraphicsView*>());
    comprobar(v,"lienzo");
    QMimeData files;
    files.setUrls({QUrl::fromLocalFile(pdf)});
    QPointF destino=v->mapFromScene(QPointF(-510,-185));
    QDragEnterEvent entrada(destino,Qt::CopyAction,&files,Qt::LeftButton,Qt::NoModifier);
    QApplication::sendEvent(v->viewport(),&entrada);
    QDropEvent soltar(destino,Qt::CopyAction,&files,Qt::LeftButton,Qt::NoModifier);
    QApplication::sendEvent(v->viewport(),&soltar);
    comprobar(entrada.isAccepted() && soltar.isAccepted(),"arrastrar un PDF");
    QApplication::clipboard()->setImage(diagrama);
    v->setFocus();QTest::keyClick(v,Qt::Key_V,Qt::ControlModifier);
    auto *pegada=dynamic_cast<Tarjeta*>(v->scene()->selectedItems().value(0));
    comprobar(pegada && pegada->tipo()=="imagen","pegar captura con Ctrl+V");
    pegada->setPos(-150,-185);
    QMimeData nota;nota.setText("Comprobar el troncal entre los dos switches antes de probar el ping.");v->recibir(&nota,{215,-185});
    QMimeData link;link.setUrls({QUrl("https://example.org/redes/vlan")});v->recibir(&link,{215,46});
    Tarjeta *doc=nullptr,*imagen=nullptr;
    for(auto *i:v->scene()->items()){auto *c=dynamic_cast<Tarjeta*>(i);if(c->tipo()=="pdf")doc=c;if(c->tipo()=="imagen")imagen=c;}
    comprobar(doc && imagen && !imagen->imagen.isNull(),"página e imagen");
    QElapsedTimer t;t.start();while((doc->paginas!=2||doc->imagen.isNull())&&t.elapsed()<5000)QTest::qWait(25);
    comprobar(doc->paginas==2&&!doc->imagen.isNull(),"render de PDF");
    doc->pagina(1);t.restart();while(doc->imagen.isNull()&&t.elapsed()<5000)QTest::qWait(25);
    comprobar(!doc->imagen.isNull(),"segunda página");
    v->scene()->clearSelection();imagen->setSelected(true);imagen->dibujar=true;
    auto puntos=[&](QPointF f){auto r=imagen->foto();return v->mapFromScene(imagen->mapToScene(r.topLeft()+QPointF(f.x()*r.width(),f.y()*r.height())));};
    QTest::mousePress(v->viewport(),Qt::LeftButton,Qt::NoModifier,puntos({.75,.19}));
    QTest::mouseMove(v->viewport(),puntos({.54,.51}));
    QTest::mouseRelease(v->viewport(),Qt::LeftButton,Qt::NoModifier,puntos({.54,.51}));
    comprobar(imagen->datos["flechas"].toArray().size()==1,"flecha sobre captura");
    imagen->dibujar=false;v->scene()->clearSelection();
    comprobar(v->scene()->items().size()==4,"cuatro tarjetas");
    QTest::qWait(320);
    if(!captura.isEmpty())comprobar(w.grab().save(captura),"captura PNG");
    v->ampliar(1.2);doc->setPos(-428,-144);
    comprobar(w.iniciar(""),"abrir pizarra libre");comprobar(v->scene()->items().isEmpty(),"aislamiento entre proyectos");
    comprobar(w.iniciar("redes"),"reabrir redes");comprobar(qAbs(v->transform().m11()-1.2)<.001,"zoom persistente");
    for(auto *i:v->scene()->items()){auto *c=dynamic_cast<Tarjeta*>(i);
        if(c->tipo()=="pdf")comprobar(c->datos["pagina"].toInt()==2 && c->pos()==QPointF(-428,-144),"página y posición persistentes");
        if(c->tipo()=="imagen")comprobar(c->datos["flechas"].toArray().size()==1 && !c->imagen.isNull(),"anotación persistente");}
    QTest::qWait(300);w.close();qInfo("Pizarra: pruebas de interacción correctas.");
}
