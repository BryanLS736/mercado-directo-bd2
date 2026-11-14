// =====================================================================
// 3c_INICIAR_REPLICA_SET.js  -  Mercado Directo (MongoDB)
// Configura el replica set "rs_mercado" con 3 nodos. Se ejecuta UNA vez,
// conectado directamente al nodo 1:
//     mongosh --port 27017 --file 3c_INICIAR_REPLICA_SET.js
//
// REPLICACIÓN ASÍNCRONA EN MONGODB
//  - Las escrituras se hacen siempre en el nodo PRIMARIO. Este las anota en
//    su "oplog" (registro de operaciones) y los SECUNDARIOS lo leen y las
//    aplican después, por su cuenta. Por eso es asíncrona: el primario
//    confirma la escritura al cliente SIN esperar a los secundarios (w:1).
//  - Los 3 nodos de este laboratorio:
//      nodo 1 (27017)  PRIMARIO      prioridad 2: gana las elecciones
//      nodo 2 (27018)  SECUNDARIO    copia casi inmediata (milisegundos)
//      nodo 3 (27019)  SECUNDARIO    OCULTO con retraso de 60 s: aplica los
//                                    cambios 1 minuto tarde. Sirve para
//                                    mostrar con claridad que es asíncrona
//                                    y como protección ante un error humano
//                                    (por ejemplo, borrar datos por error).
//    En producción el retraso suele ser de horas; aquí 60 s para la demo.
// =====================================================================

rs.initiate({
  _id: 'rs_mercado',
  members: [
    { _id: 0, host: 'localhost:27017', priority: 2 },
    { _id: 1, host: 'localhost:27018', priority: 1 },
    { _id: 2, host: 'localhost:27019', priority: 0, hidden: true, secondaryDelaySecs: 60 }
  ]
});

// Esperar a que se elija el primario (hasta 30 s)
for (let i = 0; i < 30; i++) {
  const hello = db.hello();
  if (hello.isWritablePrimary) break;
  sleep(1000);
}

const st = rs.status();
console.table(st.members.map(m => ({ nodo: m.name, estado: m.stateStr, salud: m.health })));
print('Replica set listo. Siguiente paso: crear colecciones y cargar datos (scripts 1 y 2).');
