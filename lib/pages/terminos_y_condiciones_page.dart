// Archivo: lib/pages/terminos_y_condiciones_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Asegúrate de agregar esta dependencia a tu pubspec.yaml

class TerminosYCondicionesPage extends StatelessWidget {
  const TerminosYCondicionesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final fechaActual = DateFormat('dd \'de\' MMMM \'de\' yyyy').format(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Términos y Condiciones'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  'TÉRMINOS Y CONDICIONES PARA LA CREACIÓN Y GESTIÓN DE\n'
                  'GRUPOS EN YACHAY PROMPTS\n'
                  'Fecha de Última Actualización: $fechaActual\n'
                  'Bienvenido a Yachay Prompts. Al crear y administrar un grupo\n'
                  'en nuestra plataforma, usted acepta los siguientes términos y condiciones. Le\n'
                  'pedimos que los lea detenidamente.\n\n'
                  '1. Definiciones Clave\n\n'
                  ' Plataforma:\n'
                  '     Se refiere a los servicios de Yachay Prompts, incluyendo nuestro sitio web\n'
                  '     y cualquier aplicación o función asociada.\n\n'
                  ' Grupo:\n'
                  '     Es un conjunto de usuarios que comparten un mismo plan de Yachay Prompts,\n'
                  '     el cual ha sido adquirido de forma grupal.\n\n'
                  ' Representante:\n'
                  '     Es usted, el usuario autenticado que crea y administra el Grupo. Usted es\n'
                  '     responsable de la compra del plan grupal y de invitar a los miembros.\n\n'
                  ' Miembro:\n'
                  '     Es cualquier persona que forma parte de su Grupo y que se beneficia del\n'
                  '     plan grupal que usted ha adquirido.\n\n'
                  ' Plan Grupal:\n'
                  '     Es un tipo de servicio de Yachay Prompts diseñado para ser\n'
                  '     usado por varias personas dentro de un Grupo, con características y\n'
                  '     precios específicos.\n\n'
                  ' Slot:\n'
                  '     Representa un espacio o cupo individual dentro de su Plan Grupal. Cada\n'
                  '     persona en el Grupo (incluido usted como Representante) ocupa un slot.\n\n'
                  ' Paquete:\n'
                  '     Se refiere a los paquetes de prompts o imágenes que un usuario puede\n'
                  '     comprar individualmente, independientemente de cualquier plan grupal o\n'
                  '     individual.\n'
                  '2. Quién Puede Crear un Grupo (El Representante)\n'
                  'Para poder crear un Grupo en Yachay Prompts, usted debe\n'
                  'cumplir con lo siguiente:\n\n'
                  ' Ser un Usuario Registrado y Activo: Debe tener una cuenta válida en Yachay\n'
                  '     Prompts y haber iniciado sesión.\n\n'
                  ' No Pertenecer a Otro Grupo Activo: Si usted ya es miembro de otro Grupo\n'
                  '     activo en Yachay Prompts, no podrá crear un nuevo Grupo. Para poder\n'
                  '     hacerlo, deberá salir o ser dado de baja del Grupo al que pertenece\n'
                  '     actualmente.\n\n'
                  ' Importante:\n'
                  '      Si al salir de un Grupo pierde el acceso a un "plan grupal" que\n'
                  '      tenía activo a través de ese grupo, los beneficios no consumidos de dicho\n'
                  '      plan se perderán. Sin embargo, cualquier "Paquete" de prompts o\n'
                  '      imágenes que haya comprado individualmente (no como parte de un plan) se\n'
                  '      mantendrá activo y con su saldo intacto.\n\n'
                  '3. Datos Necesarios para Crear un Grupo\n'
                  'Al crear un Grupo, se le solicitará la siguiente\n'
                  'información:\n\n'
                  ' Nombre del Grupo: Un nombre que identifique a su Grupo.\n\n'
                  ' Tipo de Plan Grupal: Deberá elegir uno de los Planes Grupales disponibles\n'
                  '     en Yachay Prompts.\n\n'
                  ' Número de Miembros: Debe indicar la cantidad total de personas que\n'
                  '     conformarán el Grupo, incluyéndolo a usted como Representante.\n\n'
                  ' Cantidad Mínima y Máxima: El Grupo debe tener como mínimo 1 miembro (usted) y\n'
                  '      un máximo de 12 miembros en total. Este límite de 12 miembros es\n'
                  '      estricto y no se puede exceder bajo ninguna circunstancia. Si usted o una\n'
                  '      institución requiere un plan para más de 12 personas, por favor, contacte\n'
                  '      a nuestro equipo de soporte para explorar nuestros "Planes Institucionales"\n'
                  '      especiales.\n\n'
                  ' Regla para el Primer Grupo: Si este es el primer Grupo que usted crea\n'
                  '      en Yachay Prompts, este Grupo debe tener un mínimo de 5 miembros en\n'
                  '      total, incluyéndolo a usted. No hay excepciones a esta regla para el\n'
                  '      primer Grupo.\n\n'
                  '4. Cómo se Calcula el Precio de su Grupo\n'
                  'El precio total de su Grupo se calculará automáticamente en\n'
                  'base al tipo de Plan Grupal elegido y al número de miembros que haya indicado,\n'
                  'siguiendo nuestra política de precios:\n\n'
                  ' Precio Base por Slot: Existe un precio base por cada "slot" o cupo\n'
                  '     dentro del Plan Grupal.\n\n'
                  ' Descuentos Especiales para el Representante: Como Representante, usted puede\n'
                  '     acceder a descuentos en el costo de su propio slot personal, los cuales\n'
                  '     dependen de cuántos Grupos haya creado y cuántos slots en total haya\n'
                  '     comprado a través de todos sus Grupos. Estos descuentos se aplican\n'
                  '     automáticamente si cumple los criterios.\n\n'
                  ' Descuento por Volumen (para Grupos de 5 o más miembros):\n\n'
                  '  Si su Grupo tiene 5 o más miembros, el precio para el resto de los\n'
                  '      miembros (además de usted) se calculará usando el precio con descuento\n'
                  '      grupal.\n\n'
                  '  Grupos Pequeños (menos de 5 miembros): Si su Grupo tiene menos de 5 miembros\n'
                  '      (y no es el primer Grupo que crea), el precio para los miembros (además\n'
                  '      de usted) se basará en el precio regular de un plan individual\n'
                  '      equivalente al plan grupal que ha elegido.\n\n'
                  ' Proceso de Pago: El pago se realizará a través de Mercado Pago. Se le\n'
                  '     redirigirá a una página segura de Mercado Pago para completar la\n'
                  '     transacción. Una vez que el pago sea exitoso, su Grupo será activado.\n'
                  '5. Creación y Gestión de su Grupo\n\n'
                  ' Estado de Pago Pendiente: Inmediatamente después de iniciar el proceso de\n'
                  '     pago, su Grupo se registrará con un estado de "pago pendiente".\n'
                  '     Este estado cambiará a "activo" una vez que Mercado Pago\n'
                  '     confirme que el pago se ha realizado con éxito.\n\n'
                  ' Código de Invitación: Una vez que su Grupo esté activo, se generará un código\n'
                  '     único de 6 caracteres para su Grupo. Usted podrá compartir este código con\n'
                  '     las personas que desee invitar para que se unan como Miembros.\n\n'
                  ' Control de Miembros: Podrá ver y gestionar a los Miembros de su Grupo,\n'
                  '     incluyendo su estado dentro del Grupo (activo, pendiente, expulsado,\n'
                  '     etc.).\n\n'
                  ' Vigencia del Plan: Cada Plan Grupal tiene una fecha de expiración, que indica\n'
                  '     hasta cuándo estará activo el servicio para su Grupo.\n'
                  '6. Sus Responsabilidades como Representante\n'
                  'Al crear un Grupo, usted se compromete a:\n\n'
                  ' Proporcionar información veraz y completa durante el proceso de creación.\n\n'
                  ' Realizar el pago completo del Plan Grupal seleccionado.\n\n'
                  ' Administrar y compartir el código de invitación del Grupo con los futuros Miembros.\n\n'
                  ' Asegurarse de que los Miembros de su Grupo cumplan con nuestras políticas de uso y\n'
                  '     términos de servicio generales de Yachay Prompts.\n\n'
                  ' Contactar a nuestro equipo de soporte en caso de cualquier problema o duda\n'
                  '     relacionada con su Grupo o el pago.\n'
                  '7. Cambios en Estos Términos y Condiciones\n'
                  'Yachay Prompts se reserva el derecho de actualizar o\n'
                  'modificar estos Términos y Condiciones en cualquier momento. Cualquier cambio\n'
                  'será publicado en nuestra Plataforma y entrará en vigencia inmediatamente. Le\n'
                  'recomendamos revisar este documento periódicamente para estar al tanto de las\n'
                  'actualizaciones.\n'
                  '8. Ley Aplicable y Jurisdicción\n'
                  'Estos Términos y Condiciones se rigen por las leyes de Perú.\n'
                  'Cualquier desacuerdo o disputa que surja en relación con estos términos será\n'
                  'resuelto exclusivamente por los tribunales competentes de Caraz, Ancash, Perú.',
                  style: TextStyle(fontSize: 14),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).pop(false);
                    },
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop(true);
                    },
                    child: const Text('Acepto'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}