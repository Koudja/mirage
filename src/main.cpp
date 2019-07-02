#include <QGuiApplication>
#include <QQmlEngine>
#include <QQmlContext>
#include <QQmlComponent>
#include <QFileInfo>
#include <QUrl>


int main(int argc, char *argv[]) {
    QGuiApplication app(argc, argv);

    QQmlEngine engine;
    QQmlContext *objectContext = new QQmlContext(engine.rootContext());

    QQmlComponent component(
        &engine,
        QFileInfo::exists("qrc:/qml/Window.qml") ?
        "qrc:/qml/Window.qml" : "src/qml/Window.qml"
    );
    component.create(objectContext);

    return app.exec();
}