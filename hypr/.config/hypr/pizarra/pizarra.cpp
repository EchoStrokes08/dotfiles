#include <QtWidgets>
#include <cmath>
#include <functional>
#include <memory>

using Json = QJsonObject;

static QColor fondo("#14171b"), panel("#20252b"), texto("#edf0f5"), tenue("#aab3c0"), acento("#ffb68e");
static QColor mezcla(QColor a, QColor b, double t) {
    return QColor::fromRgbF(a.redF()*(1-t)+b.redF()*t, a.greenF()*(1-t)+b.greenF()*t, a.blueF()*(1-t)+b.blueF()*t);
}
static void cargarTema() {
    QFile f(QStandardPaths::writableLocation(QStandardPaths::GenericStateLocation)+"/tema/colores.css");
    if (!f.open(QIODevice::ReadOnly)) return;
    const QString css = QString::fromUtf8(f.readAll());
    for (auto [nombre, color] : {std::pair{"fondo",&fondo},{"texto",&texto},{"gris",&tenue},{"acento",&acento}}) {
        auto m=QRegularExpression(QStringLiteral("@define-color\\s+%1\\s+(#[0-9a-fA-F]{6})").arg(nombre)).match(css);
        if (m.hasMatch()) *color=QColor(m.captured(1));
    }
    panel=mezcla(fondo,texto,.065);
}
static QString campo(const Json &j, const char *k) { return j.value(k).toString(); }
static QFont letra(int px, bool fuerte=false, bool mono=false) {
    QFont f(mono ? "JetBrainsMono Nerd Font" : "Adwaita Sans"); f.setPixelSize(px);
    f.setWeight(fuerte ? QFont::DemiBold : QFont::Normal); return f;
}
static bool web(const QUrl &u) { return (u.scheme()=="https" || u.scheme()=="http") && !u.host().isEmpty(); }

class Tarjeta : public QGraphicsObject {
public:
    Json datos;
    QImage imagen;
    QString aviso;
    int paginas=0;
    bool dibujar=false;
    bool encima=false;
    std::optional<QPointF> origen;
    QPointF extremo;
    std::function<void()> cambio;
    std::function<void(Tarjeta*)> activar;
    QProcess *render=nullptr;
    explicit Tarjeta(Json j): datos(std::move(j)) {
        setFlags(ItemIsMovable|ItemIsSelectable|ItemSendsGeometryChanges);
        setPos(datos["x"].toDouble(),datos["y"].toDouble());
        setCursor(Qt::OpenHandCursor);setAcceptHoverEvents(true);
        if (tipo()=="imagen") {
            QImageReader r(campo(datos,"ruta")); r.setAutoTransform(true);
            auto size=r.size(); if (size.isValid()) r.setScaledSize(size.scaled(1200,1000,Qt::KeepAspectRatio));
            imagen=r.read(); if (imagen.isNull()) aviso="Imagen no disponible";
        } else if (tipo()=="pdf") {
            auto *info=new QProcess(this);
            connect(info,&QProcess::finished,this,[this,info]{
                auto m=QRegularExpression("(?m)^Pages:\\s+(\\d+)").match(QString::fromUtf8(info->readAllStandardOutput()));
                paginas=m.captured(1).toInt(); update(); info->deleteLater();
            });
            auto env=QProcessEnvironment::systemEnvironment(); env.insert("LC_ALL","C");info->setProcessEnvironment(env);
            info->start("pdfinfo",{campo(datos,"ruta")}); pagina(0);
        }
    }
    QString tipo() const {return campo(datos,"tipo");}
    bool visual() const {return tipo()=="imagen" || tipo()=="pdf";}
    QRectF caja() const {return {0,0,visual()?336.:290.,visual()?294.:tipo()=="nota"?214.:154.};}
    QRectF boundingRect() const override {return caja().adjusted(-18,-14,18,26);}   // incluye la sombra
    QPainterPath shape() const override {QPainterPath p;p.addRoundedRect(caja(),14,14);return p;}
    QRectF area() const {return caja().adjusted(12,41,-12,-43);}
    QRectF foto() const {
        if(imagen.isNull()) return area();
        QSizeF size=imagen.size(); size.scale(area().size(),Qt::KeepAspectRatio);
        return QRectF(area().center()-QPointF(size.width()/2,size.height()/2),size);
    }
    void pagina(int delta) {
        int n=std::max(1,datos["pagina"].toInt(1)+delta);
        if(paginas) n=std::min(n,paginas);
        if(delta && (n==datos["pagina"].toInt(1) || !paginas)) return;
        datos["pagina"]=n;
        if(render) {render->disconnect(this); render->kill();render->deleteLater();}
        render=new QProcess(this); auto *proc=render;
        auto terminar=[this,proc](bool ok){
            if(proc!=render) return;
            imagen=ok ? QImage::fromData(proc->readAllStandardOutput(),"PNG") : QImage();
            aviso=imagen.isNull()?"Página no disponible":""; render=nullptr;proc->deleteLater();update();
        };
        connect(proc,&QProcess::finished,this,[terminar](int code,QProcess::ExitStatus){terminar(code==0);});
        connect(proc,&QProcess::errorOccurred,this,[terminar](QProcess::ProcessError e){if(e==QProcess::FailedToStart) terminar(false);});
        imagen={};aviso="Cargando página…";update();
        proc->start("pdftoppm",{"-f",QString::number(n),"-l",QString::number(n),"-scale-to","1000","-singlefile","-png",campo(datos,"ruta")});
        if(cambio) cambio();
    }
    static QPointF normal(QPointF p,QRectF r) {
        return {std::clamp((p.x()-r.x())/r.width(),0.,1.),std::clamp((p.y()-r.y())/r.height(),0.,1.)};
    }
    void flecha(QPainter *p,QPointF a,QPointF b) const {
        const QRectF r=foto();
        auto punto=[r](QPointF v){return r.topLeft()+QPointF(v.x()*r.width(),v.y()*r.height());};
        QLineF l(punto(a),punto(b)); if(l.length()<3) return;
        auto u=(l.p2()-l.p1())/l.length(); QPointF perp(-u.y(),u.x());
        QPainterPath trazo;trazo.moveTo(l.p1());trazo.lineTo(l.p2());
        trazo.moveTo(l.p2()-u*12+perp*6);trazo.lineTo(l.p2());trazo.lineTo(l.p2()-u*12-perp*6);
        p->setBrush(Qt::NoBrush);
        for(auto [c,w]:{std::pair{QColor("#39221c"),5}, {QColor("#ffad82"),3}}) {p->setPen(QPen(c,w,Qt::SolidLine,Qt::RoundCap,Qt::RoundJoin));p->drawPath(trazo);}
    }
    void paint(QPainter *p,const QStyleOptionGraphicsItem*,QWidget*) override {
        p->setRenderHint(QPainter::Antialiasing);p->setRenderHint(QPainter::SmoothPixmapTransform);
        auto r=caja().adjusted(1,1,-1,-1);
        QString t=tipo();
        // Sombra suave en capas: separa la tarjeta del lienzo y crece al pasar o seleccionar.
        const double alto=isSelected()?1.6:encima?1.3:1.;
        p->setPen(Qt::NoPen);
        for(int i=6;i>=1;--i){
            p->setBrush(QColor(0,0,0,int((isSelected()?15:11)*alto)));
            p->drawRoundedRect(r.adjusted(-i*1.6,-i*.8+2*alto,i*1.6,i*2.2*alto+2),14+i*1.6,14+i*1.6);
        }
        QColor tinta=t=="nota"?QColor("#e4c985"):t=="pdf"?QColor("#eba990"):t=="imagen"?QColor("#9acabe"):t=="enlace"?QColor("#aebef1"):QColor("#c4aadf");
        QColor base=mezcla(::panel,tinta,t=="nota"?.16:.05);
        p->setPen(QPen(isSelected()?acento:mezcla(base,texto,encima?.30:.15),isSelected()?2:1));p->setBrush(base);p->drawRoundedRect(r,14,14);
        // brillo superior sutil: da volumen sin cambiar el tono
        QLinearGradient brillo(r.topLeft(),r.topLeft()+QPointF(0,60));
        brillo.setColorAt(0,QColor(255,255,255,encima?16:10));brillo.setColorAt(1,QColor(255,255,255,0));
        p->setPen(Qt::NoPen);p->setBrush(brillo);p->drawRoundedRect(r.adjusted(1,1,-1,-1),13,13);
        auto linea=[&](QRectF rect,QString str,QColor color,int px,bool bold=false,bool mono=false) {
            p->setFont(letra(px,bold,mono));p->setPen(color);
            p->drawText(rect,Qt::AlignLeft|Qt::AlignVCenter,p->fontMetrics().elidedText(str,Qt::ElideRight,int(rect.width())));
        };
        p->setPen(Qt::NoPen);p->setBrush(mezcla(base,tinta,.75));p->drawRoundedRect(QRectF(15,17,7,7),3,3);
        linea({30,7,r.width()-48,26},t=="pdf"?"DOCUMENTO PDF":t.toUpper(),mezcla(texto,tinta,.28),11,true,true);
        if(visual()) {
            p->setPen(Qt::NoPen);p->setBrush(mezcla(fondo,Qt::black,.12));p->drawRoundedRect(area(),6,6);
            if(!imagen.isNull()) p->drawImage(foto(),imagen);
            else {p->setPen(tenue);p->setFont(letra(13));p->drawText(area(),Qt::AlignCenter,aviso);}
            for(const auto &it:datos["flechas"].toArray()){
                auto f=it.toArray(); if(f.size()==4)flecha(p,{f[0].toDouble(),f[1].toDouble()},{f[2].toDouble(),f[3].toDouble()});
            }
            if(origen)flecha(p,*origen,extremo);
            linea({15,r.height()-39,t=="pdf"?175.:r.width()-30,33},campo(datos,"nombre"),texto,13,true);
            if(t=="pdf")linea({196,r.height()-39,135,33},QString("‹    %1 / %2    ›").arg(datos["pagina"].toInt(1)).arg(paginas?QString::number(paginas):"…"),texto,13,true,true);
        } else if(t=="nota") {
            p->setFont(letra(19));p->setPen(texto);QRect areaTexto(17,46,255,147);
            QTextOption opt(Qt::AlignLeft);opt.setWrapMode(QTextOption::WrapAtWordBoundaryOrAnywhere);
            p->save();p->setClipRect(areaTexto);p->drawText(areaTexto,campo(datos,"texto"),opt);p->restore();
        } else {
            linea({16,40,r.width()-32,44},campo(datos,"nombre"),texto,19,true);
            linea({16,86,r.width()-32,26},t=="enlace"?QUrl(campo(datos,"url")).host():campo(datos,"title"),tenue,13);
            linea({16,115,r.width()-32,24},t=="enlace"?"Abrir enlace ↗":"Ir a la ventana ↗",texto,12,true);
        }
    }
    QVariant itemChange(GraphicsItemChange what,const QVariant &value) override {
        if(what==ItemPositionHasChanged){datos["x"]=pos().x();datos["y"]=pos().y();if(cambio)cambio();}
        return QGraphicsObject::itemChange(what,value);
    }
    void mousePressEvent(QGraphicsSceneMouseEvent *e) override {
        if(e->button()==Qt::LeftButton && dibujar && tipo()=="imagen" && !imagen.isNull() && foto().contains(e->pos())){
            origen=normal(e->pos(),foto());extremo=*origen;setSelected(true);e->accept();return;
        }
        if(e->button()==Qt::LeftButton && tipo()=="pdf" && e->pos().y()>251 && e->pos().x()>191){
            pagina(e->pos().x()<252?-1:1);e->accept();return;
        }
        QGraphicsObject::mousePressEvent(e);
    }
    void mouseMoveEvent(QGraphicsSceneMouseEvent *e) override {
        if(origen){extremo=normal(e->pos(),foto());update();return;} QGraphicsObject::mouseMoveEvent(e);
    }
    void mouseReleaseEvent(QGraphicsSceneMouseEvent *e) override {
        if(origen){auto arr=datos["flechas"].toArray(); if(QLineF(*origen,extremo).length()>.012)arr.append(QJsonArray{origen->x(),origen->y(),extremo.x(),extremo.y()});
            datos["flechas"]=arr;origen.reset();update();if(cambio)cambio();return;}
        QGraphicsObject::mouseReleaseEvent(e);
        if(e->button()==Qt::LeftButton && (tipo()=="enlace" || tipo()=="ventana") && e->pos().y()>112 &&
           (e->screenPos()-e->buttonDownScreenPos(Qt::LeftButton)).manhattanLength()<5) activar(this);
    }
    void hoverEnterEvent(QGraphicsSceneHoverEvent *e) override {encima=true;update();QGraphicsObject::hoverEnterEvent(e);}
    void hoverLeaveEvent(QGraphicsSceneHoverEvent *e) override {encima=false;update();QGraphicsObject::hoverLeaveEvent(e);}
    void mouseDoubleClickEvent(QGraphicsSceneMouseEvent *e) override { if(!dibujar)activar(this);e->accept(); }
};

class Lienzo : public QGraphicsView {
public:
    std::function<void()> modificado;
    std::function<void(const QMimeData*,QPointF)> recibir;
    explicit Lienzo(QGraphicsScene *s): QGraphicsView(s) {
        setFrameShape(QFrame::NoFrame); setAcceptDrops(true);
        setRenderHints(QPainter::Antialiasing|QPainter::SmoothPixmapTransform);
        setAlignment(Qt::AlignCenter); setDragMode(ScrollHandDrag);
        setHorizontalScrollBarPolicy(Qt::ScrollBarAlwaysOff);
        setVerticalScrollBarPolicy(Qt::ScrollBarAlwaysOff);
        setTransformationAnchor(AnchorUnderMouse);
        setResizeAnchor(AnchorViewCenter);
        setSceneRect(-1000000,-1000000,2000000,2000000);
        setFocusPolicy(Qt::StrongFocus);
    }
    QPointF centro() const {return mapToScene(viewport()->rect().center());}
    void ampliar(double factor) {
        const double actual=transform().m11();
        const double nuevo=std::clamp(actual*factor,.25,3.);
        scale(nuevo/actual,nuevo/actual);
        if(modificado) modificado();
    }
    void drawBackground(QPainter *p,const QRectF &r) override {
        p->fillRect(r,mezcla(fondo,texto,.018));
        const int paso=transform().m11()<.6?56:28;
        QPen punteado(mezcla(fondo,texto,.17));punteado.setWidthF(1.45);punteado.setCosmetic(true);
        p->setPen(punteado);
        QVector<QPointF> puntos;
        for(double x=std::floor(r.left()/paso)*paso;x<=r.right();x+=paso)
            for(double y=std::floor(r.top()/paso)*paso;y<=r.bottom();y+=paso)puntos.append({x,y});
        p->drawPoints(puntos);
    }
    bool vacio=true;
    void drawForeground(QPainter *p,const QRectF &) override {
        if(!vacio)return;
        p->save();p->resetTransform();const QRect v=viewport()->rect();
        p->translate(v.center().x(),v.center().y()-36);
        for(int i=0;i<3;++i){
            p->save();p->translate(-25+i*24,-48+(i==1?-8:0));p->rotate((i-1)*14);
            auto tinte=i==0?QColor("#9acabe"):i==1?acento:QColor("#aebef1");
            p->setBrush(mezcla(fondo,tinte,.16));p->setPen(QPen(mezcla(fondo,tinte,.70),1.2));
            p->drawRoundedRect(QRectF(-23,-28,46,56),5,5);p->setPen(QPen(tinte,2));
            p->drawLine(-14,-10,9,-10);p->drawLine(-14,-3,3,-3);p->restore();
        }
        p->setFont(letra(28,true));p->setPen(texto);
        p->drawText(QRect(-250,8,500,48),Qt::AlignCenter,"Tu pizarra está lista");
        p->setFont(letra(15));p->setPen(tenue);
        p->drawText(QRect(-245,63,490,58),Qt::AlignHCenter|Qt::TextWordWrap,
                    "Arrastra un PDF, una imagen o un enlace aquí.\nTambién puedes pegar una captura o escribir una nota.");
        p->restore();
    }
    void wheelEvent(QWheelEvent *e) override {
        if(e->modifiers() & Qt::ControlModifier){ampliar(std::pow(1.16,e->angleDelta().y()/120.));e->accept();}
        else QGraphicsView::wheelEvent(e);
    }
    void scrollContentsBy(int dx,int dy) override {
        QGraphicsView::scrollContentsBy(dx,dy); if(modificado)modificado();
    }
    void dragEnterEvent(QDragEnterEvent *e) override {
        if(qEnvironmentVariableIsSet("PIZARRA_DIAGNOSTICO"))fprintf(stderr,"arrastre: %s\n",qPrintable(e->mimeData()->formats().join(", ")));
        if(e->mimeData()->hasUrls()||e->mimeData()->hasImage()||e->mimeData()->hasText()) e->acceptProposedAction();
    }
    void dragMoveEvent(QDragMoveEvent *e) override {e->acceptProposedAction();}
    void dropEvent(QDropEvent *e) override {recibir(e->mimeData(),mapToScene(e->position().toPoint()));e->acceptProposedAction();}
};

class Pizarra : public QWidget {
    QString src, base, proyecto, carpeta;
    Json anterior;
    QGraphicsScene escena;
    Lienzo *vista;
    QComboBox *selector;
    QLabel *estado,*recuento;
    QPushButton *escala,*anotar,*quitar;
    QTimer guardado;
    std::unique_ptr<QLockFile> bloqueo;
    bool cargando=true, pendiente=false;
    int desplazamiento=0;
    QString ultimaCarpeta;
    QStringList imagenes={"png","jpg","jpeg","webp","bmp","gif","avif","tif","tiff"};
    void mensaje(const QString &s){estado->setText(s);estado->setToolTip(s);}
    void informar(const QString &s){if(qEnvironmentVariableIsSet("PIZARRA_DIAGNOSTICO"))fprintf(stderr,"aviso: %s\n",qPrintable(s));QMessageBox::information(this,"Pizarra",s);}
    QPushButton* boton(QHBoxLayout *l,const QString &titulo,const QString &tip,std::function<void()> accion) {
        auto *b=new QPushButton(titulo);b->setToolTip(tip);b->setCursor(Qt::PointingHandCursor);
        connect(b,&QPushButton::clicked,this,[accion]{accion();});l->addWidget(b);return b;
    }
    void tecla(const QKeySequence &s,std::function<void()> accion) {
        auto *a=new QShortcut(s,this);connect(a,&QShortcut::activated,this,[accion]{accion();});
    }
    QList<Tarjeta*> tarjetas() const {
        QList<Tarjeta*> todas;
        for(auto *i:escena.items(Qt::AscendingOrder)) if(auto *c=dynamic_cast<Tarjeta*>(i)) todas<<c;
        return todas;
    }
    Tarjeta* seleccion() const {
        const auto sel=escena.selectedItems();return sel.isEmpty()?nullptr:dynamic_cast<Tarjeta*>(sel.first());
    }
    void actualizar() {
        const auto cards=tarjetas();const int n=cards.size();
        vista->vacio=n==0;vista->viewport()->update();
        recuento->setText(n==1?"1 tarjeta":QString("%1 tarjetas").arg(n));
        escala->setText(QString::number(qRound(vista->transform().m11()*100))+" %");
        auto *c=seleccion();quitar->setEnabled(c);
        anotar->setEnabled(c && c->tipo()=="imagen" && !c->imagen.isNull());
        anotar->setChecked(c && c->dibujar);
    }
    void cambios() {
        if(cargando || !bloqueo)return;
        pendiente=true;guardado.start();mensaje("Guardando…");actualizar();
    }
    bool guardar() {
        if(qEnvironmentVariableIsSet("PIZARRA_DIAGNOSTICO"))fprintf(stderr,"guardar: pendiente=%d bloqueo=%d tarjetas=%lld\n",pendiente,bool(bloqueo),(long long)tarjetas().size());
        if(!pendiente || !bloqueo) return true;
        QJsonArray cards;for(auto *c:tarjetas())cards.append(c->datos);
        auto centro=vista->centro();
        Json datos{{"version",1},{"tarjetas",cards},{"zoom",vista->transform().m11()},
                   {"cx",centro.x()},{"cy",centro.y()}};
        QSaveFile f(carpeta+"/lienzo.json");
        QByteArray contenido=QJsonDocument(datos).toJson(QJsonDocument::Compact);
        if(!f.open(QIODevice::WriteOnly)||f.write(contenido)!=contenido.size()||!f.commit()){
            mensaje("Error al guardar · "+f.errorString());return false;
        }
        pendiente=false;mensaje("Guardado");return true;
    }
    void agregar(Json j,QPointF pos,bool nueva=true) {
        if(qEnvironmentVariableIsSet("PIZARRA_DIAGNOSTICO"))fprintf(stderr,"agregar: %s nueva=%d\n",qPrintable(QJsonDocument(j).toJson(QJsonDocument::Compact)),nueva);
        j["x"]=pos.x();j["y"]=pos.y();
        auto *c=new Tarjeta(j);escena.addItem(c);
        c->activar=[this](Tarjeta *card){activar(card);};c->cambio=[this]{cambios();};
        if(nueva){escena.clearSelection();c->setSelected(true);cambios();}
    }
    QPointF puntoNuevo() {
        const int d=(desplazamiento++%6)*22;
        return vista->centro()+QPointF(-145+d,-100+d);
    }
    void nota(QString contenido,QPointF pos,Tarjeta *card=nullptr) {
        bool ok=false;
        QString s=QInputDialog::getMultiLineText(this,card?"Editar nota":"Nueva nota","Texto de la nota",contenido,&ok);
        if(!ok || s.trimmed().isEmpty())return;
        if(card){card->datos["texto"]=s;card->update();cambios();}
        else agregar({{"tipo","nota"},{"texto",s}},pos);
    }
    void enlace(const QUrl &url,QPointF pos) {
        if(!web(url)){informar("Introduce un enlace http o https válido.");return;}
        agregar({{"tipo","enlace"},{"nombre",url.fileName().isEmpty()?url.host():url.fileName(QUrl::FullyDecoded)},
                 {"url",url.toString()}},pos);
    }
    void archivo(const QString &ruta,QPointF pos) {
        if(qEnvironmentVariableIsSet("PIZARRA_DIAGNOSTICO"))fprintf(stderr,"archivo: %s\n",qPrintable(ruta));
        QFileInfo f(ruta);QString ext=f.suffix().toLower();
        if(!f.isFile() || (ext!="pdf" && !imagenes.contains(ext))){
            informar("Elige un PDF o una imagen disponible en este equipo.");return;
        }
        agregar({{"tipo",ext=="pdf"?"pdf":"imagen"},{"nombre",f.fileName()},{"ruta",f.absoluteFilePath()},{"pagina",1}},pos);
    }
    void importar(const QMimeData *m,QPointF pos) {
        if(!m)return;
        if(qEnvironmentVariableIsSet("PIZARRA_DIAGNOSTICO"))
            fprintf(stderr,"importar: formatos=[%s] urls=[%s] imagen=%d texto=%d\n",qPrintable(m->formats().join(", ")),
                    qPrintable(QUrl::toStringList(m->urls()).join(" ")),m->hasImage(),m->hasText());
        if(m->hasUrls()){for(const auto &url:m->urls()){
            if(url.isLocalFile())archivo(url.toLocalFile(),pos);else enlace(url,pos);pos+=QPointF(26,26);
        }return;}
        if(m->hasImage()){
            QImage img=qvariant_cast<QImage>(m->imageData());if(img.isNull())img=qvariant_cast<QPixmap>(m->imageData()).toImage();
            QString ruta=carpeta+"/capturas/"+QUuid::createUuid().toString(QUuid::WithoutBraces)+".png";
            if(img.isNull()||!QDir().mkpath(carpeta+"/capturas")||!img.save(ruta)){
                informar("No se pudo guardar la imagen del portapapeles.");return;}
            agregar({{"tipo","imagen"},{"nombre","Captura · "+QTime::currentTime().toString("HH:mm")},{"ruta",ruta}},pos);return;
        }
        if(m->hasText()){QString s=m->text().trimmed(); if(s.isEmpty())return;
            QUrl url(s);if(web(url))enlace(url,pos);else agregar({{"tipo","nota"},{"texto",s}},pos);
        } else mensaje("El portapapeles no contiene material compatible");
    }
    QJsonValue ventanas(QString operacion, const Json &ref={},bool silencioso=false) {
        QProcess proc;proc.start("python3",{src+"/ventanas.py",operacion});
        if(!proc.waitForStarted(1200)){if(!silencioso)informar("No se pudo consultar Hyprland.");return {};}
        proc.write(QJsonDocument(ref).toJson());proc.closeWriteChannel();
        if(!proc.waitForFinished(4500)||proc.exitCode()!=0){
            if(!silencioso)informar("No se pudo completar la operación con Hyprland.\n"+QString::fromUtf8(proc.readAllStandardError()).trimmed());
            return {};
        }
        return QJsonDocument::fromJson("["+proc.readAllStandardOutput()+"]").array().at(0);
    }
    // Diálogo propio de Qt: el de GTK, abierto desde la pizarra, podía no devolver la selección.
    void elegirArchivos() {
        QFileDialog dlg(this,"Añadir a la pizarra");
        dlg.setOption(QFileDialog::DontUseNativeDialog);
        dlg.setFileMode(QFileDialog::ExistingFiles);
        dlg.setNameFilters({"Documentos e imágenes (*.pdf *.PDF *.png *.PNG *.jpg *.JPG *.jpeg *.JPEG *.webp *.gif *.bmp *.avif *.tif *.tiff)","Todos los archivos (*)"});
        // ORION guarda capturas y fondos en ~/Imágenes; la carpeta XDG de imágenes puede ser otra (vacía).
        QString imagenes=QDir::homePath()+"/Imágenes";
        if(!QFileInfo(imagenes).isDir())imagenes=QStandardPaths::writableLocation(QStandardPaths::PicturesLocation);
        dlg.setDirectory(ultimaCarpeta.isEmpty()?imagenes:ultimaCarpeta);
        dlg.setSidebarUrls({QUrl::fromLocalFile(QDir::homePath()),QUrl::fromLocalFile(imagenes),
            QUrl::fromLocalFile(imagenes+"/wallpapers"),QUrl::fromLocalFile(imagenes+"/screenshots"),
            QUrl::fromLocalFile(QStandardPaths::writableLocation(QStandardPaths::DownloadLocation)),
            QUrl::fromLocalFile(QStandardPaths::writableLocation(QStandardPaths::DocumentsLocation))});
        dlg.resize(920,600);
        if(dlg.exec()!=QDialog::Accepted)return;
        ultimaCarpeta=dlg.directory().absolutePath();
        QPointF pos=puntoNuevo();
        for(const auto &f:dlg.selectedFiles()){archivo(f,pos);pos+=QPointF(26,26);}
    }
    void pegar() {
        const QMimeData *m=QApplication::clipboard()->mimeData();
        if(!m || m->formats().isEmpty()){mensaje("El portapapeles está vacío");return;}
        importar(m,puntoNuevo());
    }
    void anclarVentana() {
        auto lista=ventanas("lista");if(!lista.isArray())return;
        auto arr=lista.toArray();if(arr.isEmpty()){informar("No hay otras ventanas abiertas.");return;}
        QDialog dlg(this);dlg.setWindowTitle("Vincular ventana");QVBoxLayout layout(&dlg);
        QListWidget opciones;for(auto w:arr){auto j=w.toObject();opciones.addItem(campo(j,"nombre")+"  ·  "+campo(j,"title"));}
        opciones.setCurrentRow(0);layout.addWidget(&opciones);
        QDialogButtonBox botones(QDialogButtonBox::Ok|QDialogButtonBox::Cancel);layout.addWidget(&botones);
        connect(&botones,&QDialogButtonBox::accepted,&dlg,&QDialog::accept);
        connect(&botones,&QDialogButtonBox::rejected,&dlg,&QDialog::reject);
        connect(&opciones,&QListWidget::itemDoubleClicked,&dlg,&QDialog::accept);
        dlg.resize(530,330);if(dlg.exec()!=QDialog::Accepted || opciones.currentRow()<0)return;
        auto j=arr[opciones.currentRow()].toObject();j["tipo"]="ventana";agregar(j,puntoNuevo());
    }
    void activar(Tarjeta *c) {
        const QString t=c->tipo();
        if(t=="nota"){nota(campo(c->datos,"texto"),c->pos(),c);return;}
        if(t=="ventana"){
            if(ventanas("activar",c->datos).toString()=="ofrecer" &&
               QMessageBox::question(this,"Ventana cerrada","¿Abrir "+campo(c->datos,"nombre")+"?")==QMessageBox::Yes)
                ventanas("abrir",c->datos);
            return;
        }
        QUrl url=t=="enlace"?QUrl(campo(c->datos,"url")):QUrl::fromLocalFile(campo(c->datos,"ruta"));
        if(!((t=="enlace" && web(url))||(c->visual() && QFileInfo(url.toLocalFile()).isFile())) || !QDesktopServices::openUrl(url))
            informar("El recurso ya no está disponible.");
    }
    void nuevoProyecto() {
        bool aceptado = false;
        QString nombre = QInputDialog::getText(this, "Nuevo proyecto de Brújula", "Nombre del proyecto",
                                               QLineEdit::Normal, {}, &aceptado).trimmed();
        if (!aceptado || nombre.isEmpty() || !guardar()) return;
        QProcess proceso;
        proceso.start("python3", {src + "/../scripts/flujo.py", "proyecto", "guardar", "--nombre=" + nombre});
        if (!proceso.waitForFinished(8000) || proceso.exitCode() != 0) {
            const Json error = QJsonDocument::fromJson(proceso.readAllStandardError()).object();
            informar(error["error"].toString("No se pudo crear el proyecto en Brújula."));
            return;
        }
        const Json respuesta = QJsonDocument::fromJson(proceso.readAllStandardOutput()).object();
        const QString id = campo(respuesta, "seleccion");
        if (id.isEmpty()) { informar("Brújula no devolvió el proyecto creado."); return; }
        selector->insertItem(selector->count() - 1, nombre, id);
        if (abrir(id)) selector->setCurrentIndex(selector->findData(id));
    }
    void retirar() {
        auto *c=seleccion();if(!c)return;
        if(QMessageBox::question(this,"Quitar tarjeta","¿Quitar esta tarjeta de la pizarra?")==QMessageBox::Yes){
            escena.removeItem(c);delete c;cambios();
        }
    }
    void encuadrar() {
        auto items=escena.itemsBoundingRect();if(items.isEmpty()){vista->resetTransform();vista->centerOn(0,0);}
        else {vista->fitInView(items.adjusted(-60,-60,60,60),Qt::KeepAspectRatio);
            double z=std::clamp(vista->transform().m11(),.25,1.);vista->setTransform(QTransform::fromScale(z,z));vista->centerOn(items.center());}
        cambios();
    }
    bool abrir(const QString &id) {
        if(!guardar())return false;
        QString dir=base+"/"+QString(QCryptographicHash::hash(id.toUtf8(),QCryptographicHash::Sha256).toHex());
        if(!QDir().mkpath(dir)){informar("No se puede crear la carpeta de la pizarra.");return false;}
        auto lock=std::make_unique<QLockFile>(dir+"/sesion.lock");
        if(!lock->tryLock()){
            qint64 pid=0; QString host, proceso;
            if(lock->getLockInfo(&pid,&host,&proceso) && ventanas("traer",{{"pid",pid}},true).toBool()) return false;
            informar("Esta pizarra ya está abierta o su carpeta no admite escritura.");return false;
        }
        QFile f(dir+"/lienzo.json");Json j;
        if(f.exists()){
            if(!f.open(QIODevice::ReadOnly)){informar("No se puede leer el proyecto.");return false;}
            j=QJsonDocument::fromJson(f.readAll()).object();
            if(j.value("version").toInt()!=1 || !j["tarjetas"].isArray()){informar("Formato de pizarra desconocido. El archivo se ha conservado.");return false;}
        }
        cargando=true;guardado.stop();escena.clear();bloqueo=std::move(lock);carpeta=dir;proyecto=id;
        for(const auto &it:j["tarjetas"].toArray()){auto card=it.toObject();agregar(card,{card["x"].toDouble(),card["y"].toDouble()},false);}
        double zoom=std::clamp(j["zoom"].toDouble(1),.25,3.);
        vista->setTransform(QTransform::fromScale(zoom,zoom));vista->centerOn(j["cx"].toDouble(),j["cy"].toDouble());
        pendiente=false;cargando=false;actualizar();mensaje("Guardado local");return true;
    }
protected:
    void closeEvent(QCloseEvent *e) override {
        if(!guardar()){informar("No se pudo guardar. La pizarra sigue abierta.");e->ignore();return;}
        e->accept();
    }
public:
    explicit Pizarra(QString fuente):src(std::move(fuente)) {
        const QString state=QStandardPaths::writableLocation(QStandardPaths::GenericStateLocation);
        base=state+"/pizarra";anterior=ventanas("origen",{},true).toObject();
        setWindowTitle("Pizarra · ORION");setMinimumSize(740,440);setFont(letra(14));
        auto *root=new QVBoxLayout(this);root->setContentsMargins(0,0,0,0);root->setSpacing(0);
        auto *cab=new QWidget;cab->setObjectName("cabecera");auto *head=new QHBoxLayout(cab);head->setContentsMargins(24,12,20,12);head->setSpacing(10);
        auto *marca=new QLabel("▦");marca->setObjectName("marca");head->addWidget(marca);
        auto *titulo=new QLabel("Pizarra");titulo->setFont(letra(23,true));head->addWidget(titulo);
        auto *div=new QLabel(" / ");div->setObjectName("sec");head->addWidget(div);
        selector=new QComboBox;selector->setAccessibleName("Proyecto");selector->addItem("Pizarra libre","");head->addWidget(selector);
        QFile f(state+"/mesa-trabajo/proyectos.json");if(f.open(QIODevice::ReadOnly)){
            auto meta=QJsonDocument::fromJson(f.readAll()).object();
            for(auto v:meta["proyectos"].toArray()){auto j=v.toObject();if(!campo(j,"id").isEmpty())selector->addItem(campo(j,"nombre"),campo(j,"id"));}
        }
        selector->addItem("Nuevo proyecto…");
        head->addStretch();estado=new QLabel;estado->setObjectName("sec");head->addWidget(estado);
        boton(head,"Salir  Esc","Volver al escritorio",[this]{volver();});root->addWidget(cab);
        auto *tools=new QHBoxLayout;tools->setContentsMargins(22,9,22,9);tools->setSpacing(6);
        auto *nuevo=boton(tools,"＋  Nota","Crear una nota (N)",[this]{nota("",puntoNuevo());});nuevo->setObjectName("primario");
        boton(tools,"Archivo","Añadir PDF o imagen",[this]{elegirArchivos();});
        boton(tools,"Pegar","Pegar imagen, enlace o texto del portapapeles (Ctrl+V)",[this]{pegar();});
        boton(tools,"Enlace","Vincular una página web",[this]{bool ok;auto s=QInputDialog::getText(this,"Añadir enlace","Dirección web",QLineEdit::Normal,"https://",&ok);if(ok)enlace(QUrl::fromUserInput(s.trimmed()),puntoNuevo());});
        boton(tools,"Ventana","Vincular una ventana abierta",[this]{anclarVentana();});
        anotar=boton(tools,"↗  Flecha","Arrastra sobre la imagen seleccionada para dibujar una flecha. Ctrl+Z quita la última.",[this]{if(auto *c=seleccion()){c->dibujar=anotar->isChecked();c->setCursor(c->dibujar?Qt::CrossCursor:Qt::OpenHandCursor);}});
        anotar->setCheckable(true);
        tecla(QKeySequence::Undo,[this] {
            auto *c = seleccion();
            if (!c || c->tipo() != "imagen") return;
            auto flechas = c->datos["flechas"].toArray();
            if (flechas.isEmpty()) return;
            flechas.removeLast();
            c->datos["flechas"] = flechas;
            c->update();
            cambios();
        });
        tools->addStretch();
        quitar=boton(tools,"Quitar","Quitar la tarjeta seleccionada (Supr)",[this]{retirar();});
        root->addLayout(tools);vista=new Lienzo(&escena);root->addWidget(vista,1);
        auto *pie=new QHBoxLayout;pie->setContentsMargins(22,8,20,8);pie->setSpacing(6);
        recuento=new QLabel;pie->addWidget(recuento);auto *ayuda=new QLabel("   ·   Arrastra el fondo para moverte");ayuda->setObjectName("sec");pie->addWidget(ayuda);
        pie->addStretch();boton(pie,"−","Alejar",[this]{vista->ampliar(1/1.2);});
        escala=boton(pie,"100 %","Restablecer zoom",[this]{vista->ampliar(1/vista->transform().m11());});
        boton(pie,"＋","Acercar",[this]{vista->ampliar(1.2);});boton(pie,"Encuadrar","Ver todas las tarjetas (F)",[this]{encuadrar();});root->addLayout(pie);
        const QHash<QString,QString> iconos{{"Archivo","document-open"},{"Pegar","edit-paste"},{"Enlace","insert-link"},
            {"Ventana","window-new"},{"Quitar","edit-delete"},{"Encuadrar","zoom-fit-best"}};
        for (auto *b : findChildren<QPushButton*>()) {
            if (iconos.contains(b->text())) {b->setIcon(QIcon::fromTheme(iconos.value(b->text())));b->setText(" "+b->text());}
        }
        setStyleSheet(QStringLiteral("QWidget{background:%1;color:%2;} QLabel#sec{color:%3;} QLabel#marca{color:%4;font-size:28px;} QWidget#cabecera{background:%5;} QWidget#cabecera QLabel{background:transparent;} QPushButton,QComboBox{padding:6px 11px;border:1px solid %6;border-radius:7px;background:%5;} QPushButton:hover,QComboBox:hover{border-color:%3;} QPushButton:focus,QComboBox:focus{border-color:%4;} QPushButton:checked,QPushButton#primario{background:%4;color:%7;} QPushButton:disabled{color:%6;border-color:%6;} QLineEdit,QTextEdit,QListWidget{padding:8px;border:1px solid %6;border-radius:6px;} QListWidget::item:selected{background:%6;}").arg(fondo.name(),texto.name(),tenue.name(),acento.name(),panel.name(),mezcla(panel,texto,.19).name(),acento.lightnessF()>.5?"#101419":"#ffffff"));
        guardado.setSingleShot(true);guardado.setInterval(260);connect(&guardado,&QTimer::timeout,this,[this]{guardar();});
        vista->recibir=[this](auto *m,auto p){importar(m,p);};vista->modificado=[this]{cambios();};
        connect(&escena,&QGraphicsScene::selectionChanged,this,[this]{if(!cargando){for(auto *c:tarjetas())if(!c->isSelected()&&c->dibujar){c->dibujar=false;c->setCursor(Qt::OpenHandCursor);}actualizar();}});
        tecla(QKeySequence::Paste,[this]{pegar();});
        tecla(QKeySequence(Qt::Key_Escape),[this]{volver();});tecla(QKeySequence(Qt::Key_N),[this]{nota("",puntoNuevo());});
        tecla(QKeySequence(Qt::Key_F),[this]{encuadrar();});tecla(QKeySequence::Delete,[this]{retirar();});
        connect(selector,&QComboBox::activated,this,[this](int i){
            if (!selector->itemData(i).isValid()) {
                selector->setCurrentIndex(selector->findData(proyecto));
                nuevoProyecto();
                return;
            }
            QString id=selector->itemData(i).toString();
            if(id!=proyecto && !abrir(id))selector->setCurrentIndex(selector->findData(proyecto));});
    }
    ~Pizarra() override {cargando=true;vista->modificado=nullptr;escena.disconnect(this);escena.clear();}
    bool iniciar(QString id) {
        int i=selector->findData(id);selector->setCurrentIndex(i<0?0:i);return abrir(selector->currentData().toString());
    }
    void volver(){if(close() && !campo(anterior,"address").isEmpty())ventanas("volver",anterior,true);}
};

int main(int argc,char **argv) {
    QApplication app(argc,argv);app.setApplicationName("orion-pizarra");app.setDesktopFileName("orion-pizarra");
    app.setStyle("Fusion");cargarTema();
    QTranslator qt;   // botones estándar de los diálogos en el idioma del sistema
    if(qt.load(QLocale(),"qtbase","_",QLibraryInfo::path(QLibraryInfo::TranslationsPath)))app.installTranslator(&qt);
    auto args=app.arguments();if(args.size()<2)return 1;
    Pizarra w(args[1]);w.resize(1280,800);w.show();app.processEvents();
    if(!w.iniciar(args.value(2)))return 1;
    return app.exec();
}
