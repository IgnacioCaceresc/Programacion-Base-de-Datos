--Caso 1: Creacion del Trigger usando AFTER--

CREATE OR REPLACE TRIGGER trg_actualiza_consumos
AFTER INSERT OR UPDATE OR DELETE ON consumo
FOR EACH ROW
BEGIN
    IF INSERTING THEN
        --Añadimos el monto el consumo ya existente--
        UPDATE total_consumos
        SET monto_consumos = monto_consumos + :NEW.monto
        WHERE id_huesped = :NEW.id_huesped;
        
        --Si el huesped no existe, se inserta en la  tabla--
        IF SQL%ROWCOUNT = 0 THEN
            INSERT INTO total_consumos (id_huesped, monto_consumos)
            VALUES (:NEW.id_huesped, :NEW.monto);
        END IF;
        
    ELSIF UPDATING THEN
        --Se resta el monto antiguo y se suma el nuevo--
        UPDATE total_consumos
        SET monto_consumos = monto_consumos - :OLD.monto + :NEW.monto
        WHERE id_huesped = :NEW.id_huesped;
        
    ELSIF DELETING THEN
        --Restamos el monto del consumo que eliminamos--
        UPDATE total_consumos
        SET monto_consumos = monto_consumos - :OLD.monto
        WHERE id_huesped = :OLD.id_huesped;
    END IF;
END;
/

----------------Creacion del bloque anónimo para prueba-------------------

SET SERVEROUTPUT OFF;

DECLARE
    v_siguiente_id consumo.id_consumo%TYPE;
BEGIN
    --Buscamos el ID siguiente--
    SELECT NVL(MAX(id_consumo), 0) + 1 
    INTO v_siguiente_id 
    FROM consumo;
    
    --Se inseta el nuevo consumo con los datos de la guía de instrucciones--
    INSERT INTO consumo (id_consumo, id_reserva, id_huesped, monto)
    VALUES (v_siguiente_id, 1587, 340006, 150);
    
    --Se elimina el consumo con id 11473--
    DELETE FROM consumo 
    WHERE id_consumo = 11473;
    
    --Actualizamos a 95$ el consumo con ID 10688--
    UPDATE consumo 
    SET monto = 95 
    WHERE id_consumo = 10688;
    
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Prueba del Caso 1 ejecutada con éxito.');
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
END;
/

--Consulta de verificación huésped con nuevo consumo--
SELECT * FROM total_consumos WHERE id_huesped = 340006; --Al haberle sumado 150$ sumado a los 278 que tenía inicialmente el resultado debería arrojar 428$--

--Consulta para verificar eliminacion de registro 11473 y adición de registro 10688--
SELECT * FROM consumo WHERE id_consumo IN (11473, 10688);
--Consulta sobre el total de consumos actualizados--
SELECT * FROM total_consumos ORDER BY id_huesped;
--Consulta sobre cada consumo ordenado por el id del huesped--
SELECT * FROM consumo ORDER BY id_huesped;

-------------------Caso 2-------------------
--Package para determinar el monto en dolares a pagar--
--Cabecera--
CREATE OR REPLACE PACKAGE pkg_cobros_hotel IS
    v_monto_tours NUMBER;
    
    FUNCTION fn_monto_tours(p_id_huesped IN NUMBER) RETURN NUMBER;
END pkg_cobros_hotel;
/
--Cuerpo--
CREATE OR REPLACE PACKAGE BODY pkg_cobros_hotel IS

    FUNCTION fn_monto_tours(p_id_huesped IN NUMBER) RETURN NUMBER IS
        v_total NUMBER := 0;
    BEGIN
        -- Calculamos el total sumando (valor del tour * numero de personas)
        -- Cruzamos la tabla huesped_tour con la tabla tour
        SELECT NVL(SUM(t.valor_tour * ht.num_personas), 0)
        INTO v_total
        FROM huesped_tour ht
        JOIN tour t ON ht.id_tour = t.id_tour
        WHERE ht.id_huesped = p_id_huesped;
        
        -- Guardamos en la variable pública del package por si se necesita
        v_monto_tours := v_total;
        
        RETURN v_total;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN 0;
        WHEN OTHERS THEN
            RETURN 0;
    END fn_monto_tours;

END pkg_cobros_hotel;
/

--Creacion de Función para obtener la agencia del huesped--

CREATE OR REPLACE FUNCTION fn_obtener_agencia(p_id_huesped IN NUMBER) RETURN VARCHAR2 IS
    v_nom_agencia agencia.nom_agencia%TYPE;
    v_msg_error VARCHAR2(300);
    
    PRAGMA AUTONOMOUS_TRANSACTION; 
BEGIN
    SELECT a.nom_agencia
    INTO v_nom_agencia
    FROM huesped h
    JOIN agencia a ON h.id_agencia = a.id_agencia
    WHERE h.id_huesped = p_id_huesped;

    RETURN v_nom_agencia;
    
EXCEPTION
    WHEN OTHERS THEN
        -- Aquí armamos el mensaje exacto que viste en tu Figura 4
        v_msg_error := 'Error en la función FN_OBTENER_AGENCIA al recuperar la agencia del cliente con id ' || p_id_huesped || ' - ' || SUBSTR(SQLERRM, 1, 150);
        
        INSERT INTO reg_errores (id_error, nomsubprograma, msg_error)
        VALUES (sq_error.NEXTVAL, 'FN_OBTENER_AGENCIA', v_msg_error);
        
        COMMIT;
        
        RETURN 'NO REGISTRA AGENCIA';
END fn_obtener_agencia;
/
--Creacion de funcion para obtener los consumos del huesped--

CREATE OR REPLACE FUNCTION fn_obtener_consumos(p_id_huesped IN NUMBER) RETURN NUMBER IS
    v_monto NUMBER := 0;
    v_msg_error VARCHAR2(300);
    
    PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
    SELECT monto_consumos
    INTO v_monto
    FROM total_consumos
    WHERE id_huesped = p_id_huesped;
    
    RETURN v_monto;
    
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        v_msg_error := 'Error en la función FN_OBTENER_CONSUMOS al recuperar los consumos del cliente con id ' || p_id_huesped || ' - ' || SUBSTR(SQLERRM, 1, 150);
        
        INSERT INTO reg_errores (id_error, nomsubprograma, msg_error)
        VALUES (sq_error.NEXTVAL, 'FN_OBTENER_CONSUMOS', v_msg_error);
        
        COMMIT;
        RETURN 0;
    WHEN OTHERS THEN
        v_msg_error := 'Error en la función FN_OBTENER_CONSUMOS al recuperar los consumos del cliente con id ' || p_id_huesped || ' - ' || SUBSTR(SQLERRM, 1, 150);
        
        INSERT INTO reg_errores (id_error, nomsubprograma, msg_error)
        VALUES (sq_error.NEXTVAL, 'FN_OBTENER_CONSUMOS', v_msg_error);
        
        COMMIT;
        RETURN 0;
END fn_obtener_consumos;
/

--Procedure para generacio de cobros--

CREATE OR REPLACE PROCEDURE prc_generar_cobros (
    p_fecha_proceso IN DATE,
    p_valor_dolar IN NUMBER
) IS
    --Cursos para ver huespedes que tienen salida en fecha--
    CURSOR c_salidas IS
        SELECT r.id_huesped,
               MAX(h.nom_huesped || ' ' || h.appat_huesped || ' ' || h.apmat_huesped) AS nombre_completo,
               -- Alojamiento diario por días de estadía (Sumado para agrupar habitaciones)--
               SUM((hab.valor_habitacion + hab.valor_minibar) * r.estadia) AS alojamiento_usd,
               -- Definir numero de personas en función del tipo de habitación (Sumado para agrupar habitaciones)--
               SUM(CASE hab.tipo_habitacion
                   WHEN 'S' THEN 1
                   WHEN 'D' THEN 2
                   WHEN 'T' THEN 3
                   WHEN 'C' THEN 4
                   ELSE 2 
               END) AS cant_personas
        FROM reserva r
        JOIN huesped h ON r.id_huesped = h.id_huesped
        JOIN detalle_reserva dr ON r.id_reserva = dr.id_reserva
        JOIN habitacion hab ON dr.id_habitacion = hab.id_habitacion
        WHERE r.ingreso + r.estadia = p_fecha_proceso
        GROUP BY r.id_huesped;

    --Variables de cálculo en Dólares
    v_agencia VARCHAR2(100);
    v_tours_usd NUMBER;
    v_consumos_usd NUMBER;
    v_cobro_personas_usd NUMBER;
    
    v_subtotal_usd NUMBER;
    v_descuento_agencia_usd NUMBER := 0;
    v_descuento_consumos_usd NUMBER := 0;
    v_pct_desc_consumos NUMBER := 0;
    v_total_pagar_usd NUMBER;
BEGIN
    --Limpiar las tablas según el requerimiento--
    DELETE FROM detalle_diario_huespedes;
    DELETE FROM reg_errores;
    
    COMMIT;

    --Recorrer todos los huéspedes del día--
    FOR r_huesped IN c_salidas LOOP
        
        --Invocar funciones y package--
        v_agencia := fn_obtener_agencia(r_huesped.id_huesped);
        v_consumos_usd := fn_obtener_consumos(r_huesped.id_huesped);
        v_tours_usd := pkg_cobros_hotel.fn_monto_tours(r_huesped.id_huesped);

        --Cálculos base en dolares--
        -- Cobro por personas: Transformamos los 35.000 a dolares para sumarlos al subtotal--
        v_cobro_personas_usd := (35000 / p_valor_dolar) * r_huesped.cant_personas;

        --Subtotal (Alojamiento + Consumos + Valor por persona)--
        v_subtotal_usd := r_huesped.alojamiento_usd + v_consumos_usd + v_cobro_personas_usd;

        --Descuento Agencia--
        IF v_agencia = 'VIAJES ALBERTI' THEN
            v_descuento_agencia_usd := v_subtotal_usd * 0.12;
        ELSE
            v_descuento_agencia_usd := 0;
        END IF;

        --Descuento Consumos--
        BEGIN
            SELECT pct INTO v_pct_desc_consumos
            FROM tramos_consumos
            WHERE v_consumos_usd BETWEEN vmin_tramo AND vmax_tramo;
            
            v_descuento_consumos_usd := v_consumos_usd * v_pct_desc_consumos;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                v_descuento_consumos_usd := 0;
        END;

        --Total a Pagar en Dólares (Subtotal + Tours - Descuentos)--        
        v_total_pagar_usd := (v_subtotal_usd + v_tours_usd) - v_descuento_agencia_usd - v_descuento_consumos_usd;

        --Insertar el resultado final convirtiendo a pesos--
        INSERT INTO detalle_diario_huespedes (
            id_huesped, nombre, agencia, alojamiento, consumos, tours, 
            subtotal_pago, descuento_consumos, descuentos_agencia, total
        ) VALUES (
            r_huesped.id_huesped,
            r_huesped.nombre_completo,
            v_agencia,
            ROUND(r_huesped.alojamiento_usd * p_valor_dolar),
            ROUND(v_consumos_usd * p_valor_dolar),
            ROUND(v_tours_usd * p_valor_dolar),
            ROUND(v_subtotal_usd * p_valor_dolar),
            ROUND(v_descuento_consumos_usd * p_valor_dolar),
            ROUND(v_descuento_agencia_usd * p_valor_dolar),
            ROUND(v_total_pagar_usd * p_valor_dolar)
        );
        
    END LOOP;
    
    COMMIT;
END prc_generar_cobros;
/

BEGIN
    prc_generar_cobros(TO_DATE('18/08/2021', 'DD/MM/YYYY'), 915);
END;
/

--Consulta huespedes que marcaron salida 18/08/2021--
SELECT * FROM detalle_diario_huespedes ORDER BY id_huesped;

--Consulta para ver el registro de errores--
SELECT * FROM reg_errores ORDER BY id_error;