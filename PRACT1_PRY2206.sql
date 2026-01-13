/*
================================================================================
BLOQUE PL/SQL ANÓNIMO - PROGRAMA PESOS TODOSUMA

*/

SET SERVEROUTPUT OFF;

DECLARE

    
    -- RUN del cliente a procesar (sin dígito verificador)
    v_run_cliente NUMBER := &Ingrese_RUN_Cliente; --Ingresar 21242003
                                                  --Ingresar 22176844
                                                  --Ingresar 18858542
                                                  --Ingresar 21300628
                                                  --Ingresar 22558061
    -- Tramos para pesos extras (Trabajadores Independientes)
    v_tramo1_min NUMBER := &Tramo1_Minimo;           -- Escribir: 0
    v_tramo1_max NUMBER := &Tramo1_Maximo;           -- Escribir: 1000000
    v_tramo2_min NUMBER := &Tramo2_Minimo;           -- Escribir: 1000001
    v_tramo2_max NUMBER := &Tramo2_Maximo;           -- Escribir: 3000000
    v_tramo3_min NUMBER := &Tramo3_Minimo;           -- Escribir: 3000001
    
    -- Valores de pesos
    v_pesos_normales NUMBER := &Pesos_Normales;      -- Escribir: 1200
    v_pesos_extra_t1 NUMBER := &Pesos_Extra_Tramo1;  -- Escribir: 100
    v_pesos_extra_t2 NUMBER := &Pesos_Extra_Tramo2;  -- Escribir: 300
    v_pesos_extra_t3 NUMBER := &Pesos_Extra_Tramo3;  -- Escribir: 550
    
    -- ========================================================================
    -- VARIABLES DE TRABAJO
    -- ========================================================================
    
    -- Datos del cliente
    v_nro_cliente NUMBER;
    v_run_completo VARCHAR2(15);
    v_nombre_cliente VARCHAR2(50);
    v_tipo_cliente VARCHAR2(30);
    
    -- Cálculos de créditos
    v_suma_montos_solicitados NUMBER := 0;
    v_monto_pesos_todosuma NUMBER := 0;
    
    -- Variables auxiliares para cálculos
    v_cantidad_centenas NUMBER;
    v_pesos_base NUMBER := 0;
    v_pesos_extras NUMBER := 0;
    
    -- Año a procesar (año anterior al actual)
    v_anio_proceso NUMBER;
    
    -- Control de existencia
    v_existe_cliente NUMBER := 0;
    v_tiene_creditos NUMBER := 0;
    
    -- CURSOR: Obtiene créditos del cliente en el año anterior
    
    CURSOR cur_creditos IS
        SELECT monto_solicitado
        FROM CREDITO_CLIENTE
        WHERE nro_cliente = v_nro_cliente
        AND EXTRACT(YEAR FROM fecha_otorga_cred) = v_anio_proceso;
    
BEGIN
    -- ========================================================================
    -- 1. INICIALIZACIÓN Y VALIDACIONES
    -- ========================================================================
    
    DBMS_OUTPUT.PUT_LINE('================================================================================');
    DBMS_OUTPUT.PUT_LINE('PROCESANDO PROGRAMA PESOS TODOSUMA');
    DBMS_OUTPUT.PUT_LINE('================================================================================');
    DBMS_OUTPUT.PUT_LINE('');
    
    -- Calcular el año a procesar (año anterior al actual)
    v_anio_proceso := EXTRACT(YEAR FROM SYSDATE) - 1;
    DBMS_OUTPUT.PUT_LINE('Año de proceso: ' || v_anio_proceso);
    DBMS_OUTPUT.PUT_LINE('');
    
    -- ========================================================================
    -- 2. BUSCAR INFORMACIÓN DEL CLIENTE
    -- ========================================================================
    
    -- Verificar si el cliente existe
    SELECT COUNT(*)
    INTO v_existe_cliente
    FROM CLIENTE
    WHERE numrun = v_run_cliente;
    
    -- Si el cliente no existe, terminar el proceso
    IF v_existe_cliente = 0 THEN
        DBMS_OUTPUT.PUT_LINE('ERROR: No existe cliente con RUN ' || v_run_cliente);
        RETURN;
    END IF;
    
    -- Obtener datos del cliente
    SELECT 
        c.nro_cliente,
        c.numrun || '-' || c.dvrun,
        TRIM(c.pnombre || ' ' || NVL(c.snombre, '') || ' ' || c.appaterno || ' ' || NVL(c.apmaterno, '')),
        tc.nombre_tipo_cliente
    INTO 
        v_nro_cliente,
        v_run_completo,
        v_nombre_cliente,
        v_tipo_cliente
    FROM CLIENTE c
    INNER JOIN TIPO_CLIENTE tc ON c.cod_tipo_cliente = tc.cod_tipo_cliente
    WHERE c.numrun = v_run_cliente;
    
    DBMS_OUTPUT.PUT_LINE('Cliente encontrado:');
    DBMS_OUTPUT.PUT_LINE('  Número: ' || v_nro_cliente);
    DBMS_OUTPUT.PUT_LINE('  RUN: ' || v_run_completo);
    DBMS_OUTPUT.PUT_LINE('  Nombre: ' || v_nombre_cliente);
    DBMS_OUTPUT.PUT_LINE('  Tipo: ' || v_tipo_cliente);
    DBMS_OUTPUT.PUT_LINE('');
    
    -- ========================================================================
    -- 3. VERIFICAR SI TIENE CRÉDITOS EN EL AÑO ANTERIOR
    -- ========================================================================
    
    SELECT COUNT(*)
    INTO v_tiene_creditos
    FROM CREDITO_CLIENTE
    WHERE nro_cliente = v_nro_cliente
    AND EXTRACT(YEAR FROM fecha_otorga_cred) = v_anio_proceso;
    
    -- Si no tiene créditos, terminar el proceso
    IF v_tiene_creditos = 0 THEN
        DBMS_OUTPUT.PUT_LINE('AVISO: El cliente no tiene créditos otorgados en el año ' || v_anio_proceso);
        RETURN;
    END IF;
    
    DBMS_OUTPUT.PUT_LINE('Créditos encontrados: ' || v_tiene_creditos);
    DBMS_OUTPUT.PUT_LINE('');
    
    -- ========================================================================
    -- 4. CALCULAR SUMA DE MONTOS SOLICITADOS
    -- ========================================================================
    
    DBMS_OUTPUT.PUT_LINE('Procesando créditos:');
    DBMS_OUTPUT.PUT_LINE('--------------------------------------------------');
    
    -- Recorrer todos los créditos del cliente en el año
    FOR rec_credito IN cur_creditos LOOP
        -- Acumular monto solicitado
        v_suma_montos_solicitados := v_suma_montos_solicitados + rec_credito.monto_solicitado;
        DBMS_OUTPUT.PUT_LINE('  Crédito: $' || TO_CHAR(rec_credito.monto_solicitado, '999,999,999'));
    END LOOP;
    
    DBMS_OUTPUT.PUT_LINE('--------------------------------------------------');
    DBMS_OUTPUT.PUT_LINE('Total solicitado: $' || TO_CHAR(v_suma_montos_solicitados, '999,999,999'));
    DBMS_OUTPUT.PUT_LINE('');
    
    -- ========================================================================
    -- 5. CALCULAR PESOS BASE (TODOS LOS CLIENTES)
    -- ========================================================================
    
    -- Calcular cuántas centenas de mil hay en el monto total
    v_cantidad_centenas := TRUNC(v_suma_montos_solicitados / 100000);
    
    -- Calcular pesos base: $1.200 por cada $100.000
    v_pesos_base := v_cantidad_centenas * v_pesos_normales;
    
    DBMS_OUTPUT.PUT_LINE('Cálculo de Pesos Base:');
    DBMS_OUTPUT.PUT_LINE('  Centenas de $100.000: ' || v_cantidad_centenas);
    DBMS_OUTPUT.PUT_LINE('  Pesos normales: $' || v_pesos_normales || ' x ' || v_cantidad_centenas || ' = $' || 
                         TO_CHAR(v_pesos_base, '999,999,999'));
    DBMS_OUTPUT.PUT_LINE('');
    
    -- ========================================================================
    -- 6. CALCULAR PESOS EXTRAS (SOLO TRABAJADORES INDEPENDIENTES)
    -- ========================================================================
    
    -- Verificar si es trabajador independiente
    IF v_tipo_cliente = 'Trabajadores independientes' THEN
        DBMS_OUTPUT.PUT_LINE('Cliente es Trabajador Independiente - Calculando pesos extras:');
        
        -- Estructura condicional para determinar el tramo
        IF v_suma_montos_solicitados < v_tramo1_max THEN
            -- TRAMO 1: Menor a $1.000.000 → $100 extra por cada $100.000
            v_pesos_extras := v_cantidad_centenas * v_pesos_extra_t1;
            DBMS_OUTPUT.PUT_LINE('  Tramo 1 (< $' || TO_CHAR(v_tramo1_max, '999,999,999') || ')');
            DBMS_OUTPUT.PUT_LINE('  Pesos extras: $' || v_pesos_extra_t1 || ' x ' || v_cantidad_centenas || ' = $' || 
                                 TO_CHAR(v_pesos_extras, '999,999,999'));
            
        ELSIF v_suma_montos_solicitados >= v_tramo2_min AND v_suma_montos_solicitados <= v_tramo2_max THEN
            -- TRAMO 2: $1.000.001 - $3.000.000 → $300 extra por cada $100.000
            v_pesos_extras := v_cantidad_centenas * v_pesos_extra_t2;
            DBMS_OUTPUT.PUT_LINE('  Tramo 2 ($' || TO_CHAR(v_tramo2_min, '999,999,999') || ' - $' || 
                                 TO_CHAR(v_tramo2_max, '999,999,999') || ')');
            DBMS_OUTPUT.PUT_LINE('  Pesos extras: $' || v_pesos_extra_t2 || ' x ' || v_cantidad_centenas || ' = $' || 
                                 TO_CHAR(v_pesos_extras, '999,999,999'));
            
        ELSIF v_suma_montos_solicitados > v_tramo3_min THEN
            -- TRAMO 3: Más de $3.000.000 → $550 extra por cada $100.000
            v_pesos_extras := v_cantidad_centenas * v_pesos_extra_t3;
            DBMS_OUTPUT.PUT_LINE('  Tramo 3 (> $' || TO_CHAR(v_tramo3_min, '999,999,999') || ')');
            DBMS_OUTPUT.PUT_LINE('  Pesos extras: $' || v_pesos_extra_t3 || ' x ' || v_cantidad_centenas || ' = $' || 
                                 TO_CHAR(v_pesos_extras, '999,999,999'));
        END IF;
        
    ELSE
        DBMS_OUTPUT.PUT_LINE('Cliente NO es Trabajador Independiente - Sin pesos extras');
        v_pesos_extras := 0;
    END IF;
    
    DBMS_OUTPUT.PUT_LINE('');
    
    -- ========================================================================
    -- 7. CALCULAR TOTAL DE PESOS TODOSUMA
    -- ========================================================================
    
    v_monto_pesos_todosuma := v_pesos_base + v_pesos_extras;
    
    DBMS_OUTPUT.PUT_LINE('RESUMEN DE CÁLCULO:');
    DBMS_OUTPUT.PUT_LINE('  Pesos Base:   $' || TO_CHAR(v_pesos_base, '999,999,999'));
    DBMS_OUTPUT.PUT_LINE('  Pesos Extras: $' || TO_CHAR(v_pesos_extras, '999,999,999'));
    DBMS_OUTPUT.PUT_LINE('  TOTAL:        $' || TO_CHAR(v_monto_pesos_todosuma, '999,999,999'));
    DBMS_OUTPUT.PUT_LINE('');
    
    -- ========================================================================
    -- 8. ELIMINAR REGISTRO PREVIO (SI EXISTE)
    -- ========================================================================
    
    DELETE FROM CLIENTE_TODOSUMA
    WHERE nro_cliente = v_nro_cliente;
    
    IF SQL%ROWCOUNT > 0 THEN
        DBMS_OUTPUT.PUT_LINE('Registro previo eliminado para permitir nueva inserción');
    END IF;
    
    -- ========================================================================
    -- 9. INSERTAR RESULTADO EN TABLA CLIENTE_TODOSUMA
    -- ========================================================================
    
    INSERT INTO CLIENTE_TODOSUMA (
        nro_cliente,
        run_cliente,
        nombre_cliente,
        tipo_cliente,
        monto_solic_creditos,
        monto_pesos_todosuma
    ) VALUES (
        v_nro_cliente,
        v_run_completo,
        v_nombre_cliente,
        v_tipo_cliente,
        v_suma_montos_solicitados,
        v_monto_pesos_todosuma
    );
    
    -- Confirmar la transacción
    COMMIT;
    
    DBMS_OUTPUT.PUT_LINE('================================================================================');
    DBMS_OUTPUT.PUT_LINE('PROCESO COMPLETADO EXITOSAMENTE');
    DBMS_OUTPUT.PUT_LINE('Datos almacenados en tabla CLIENTE_TODOSUMA');
    DBMS_OUTPUT.PUT_LINE('================================================================================');
    
EXCEPTION
    -- ========================================================================
    -- MANEJO DE ERRORES
    -- ========================================================================
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('ERROR: No se encontraron datos para el cliente con RUN ' || v_run_cliente);
        ROLLBACK;
        
    WHEN TOO_MANY_ROWS THEN
        DBMS_OUTPUT.PUT_LINE('ERROR: Se encontraron múltiples registros para el RUN ' || v_run_cliente);
        ROLLBACK;
        
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('ERROR INESPERADO: ' || SQLERRM);
        DBMS_OUTPUT.PUT_LINE('Código de error: ' || SQLCODE);
        ROLLBACK;
        
END;
/

/*
CONSULTA PARA VERIFICAR RESULTADOS:
-------------------------------------------------
*/
SELECT * FROM CLIENTE_TODOSUMA ORDER BY nro_cliente;

--------------------------------------------
------------------CASO N°2------------------

/*
================================================================================
BLOQUE PL/SQL ANÓNIMO - POSTERGACIÓN DE CUOTAS DE CRÉDITO

Reglas de Negocio:
- Crédito Hipotecario: 1 cuota sin interés o 2 cuotas con 0.5% interés
- Crédito de Consumo: 1 cuota con 1% de interés
- Crédito Automotriz: 1 cuota con 2% de interés
- Bonificación: Si solicitó >1 crédito año anterior → condona última cuota original

================================================================================
*/

SET SERVEROUTPUT OFF;

-- ============================================================================
-- CONFIGURACIÓN DE PARÁMETROS
-- ============================================================================
-- MODIFICA ESTOS VALORES SEGÚN EL CLIENTE A PROCESAR
DEFINE p_nro_cliente = 13
DEFINE p_nro_solic_credito = 2004
DEFINE p_cant_cuotas_postergar = 1
-- ============================================================================

DECLARE
    -- ========================================================================
    -- VARIABLES DE ENTRADA (PARÁMETROS)
    -- ========================================================================
    
    v_nro_cliente NUMBER := &p_nro_cliente;
    v_nro_solic_credito NUMBER := &p_nro_solic_credito;
    v_cant_cuotas_postergar NUMBER := &p_cant_cuotas_postergar;
    
    -- ========================================================================
    -- VARIABLES DE INFORMACIÓN DEL CLIENTE Y CRÉDITO
    -- ========================================================================
    
    v_nombre_cliente VARCHAR2(150);
    v_cod_credito NUMBER;
    v_nombre_credito VARCHAR2(50);
    v_total_cuotas_original NUMBER;
    
    -- ========================================================================
    -- VARIABLES PARA LA ÚLTIMA CUOTA ORIGINAL
    -- ========================================================================
    
    v_ultimo_nro_cuota NUMBER;
    v_ultima_fecha_venc DATE;
    v_valor_ultima_cuota NUMBER;
    
    -- ========================================================================
    -- VARIABLES PARA CÁLCULO DE NUEVAS CUOTAS
    -- ========================================================================
    
    v_tasa_interes NUMBER := 0;
    v_valor_nueva_cuota NUMBER;
    v_nueva_fecha_venc DATE;
    v_nuevo_nro_cuota NUMBER;
    
    -- ========================================================================
    -- VARIABLES PARA BONIFICACIÓN
    -- ========================================================================
    
    v_cant_creditos_anio_anterior NUMBER := 0;
    v_aplica_condonacion BOOLEAN := FALSE;
    v_anio_proceso NUMBER;
    
    -- ========================================================================
    -- VARIABLES DE CONTROL
    -- ========================================================================
    
    v_existe_credito NUMBER := 0;
    v_contador NUMBER;
    
BEGIN
    -- ========================================================================
    -- 1. INICIALIZACIÓN Y ENCABEZADO
    -- ========================================================================
    
    DBMS_OUTPUT.PUT_LINE('================================================================================');
    DBMS_OUTPUT.PUT_LINE('PROCESO DE POSTERGACIÓN DE CUOTAS DE CRÉDITO');
    DBMS_OUTPUT.PUT_LINE('================================================================================');
    DBMS_OUTPUT.PUT_LINE('');
    
    -- Calcular año de proceso (año anterior al actual)
    v_anio_proceso := EXTRACT(YEAR FROM SYSDATE) - 1;
    
    -- ========================================================================
    -- 2. VALIDAR EXISTENCIA DEL CRÉDITO
    -- ========================================================================
    
    DBMS_OUTPUT.PUT_LINE('VALIDANDO INFORMACIÓN...');
    DBMS_OUTPUT.PUT_LINE('--------------------------------------------------');
    
    -- Verificar si existe el crédito para el cliente especificado
    SELECT COUNT(*)
    INTO v_existe_credito
    FROM CREDITO_CLIENTE
    WHERE nro_solic_credito = v_nro_solic_credito
    AND nro_cliente = v_nro_cliente;
    
    -- Si no existe el crédito, terminar el proceso
    IF v_existe_credito = 0 THEN
        DBMS_OUTPUT.PUT_LINE('ERROR: No existe el crédito ' || v_nro_solic_credito || 
                            ' para el cliente ' || v_nro_cliente);
        RETURN;
    END IF;
    
    DBMS_OUTPUT.PUT_LINE('✓ Crédito encontrado');
    
    -- ========================================================================
    -- 3. OBTENER INFORMACIÓN DEL CLIENTE Y CRÉDITO
    -- ========================================================================
    
    -- Obtener datos del cliente y tipo de crédito
    SELECT 
        TRIM(cl.pnombre || ' ' || NVL(cl.snombre, '') || ' ' || 
             cl.appaterno || ' ' || NVL(cl.apmaterno, '')),
        cc.cod_credito,
        cr.nombre_credito,
        cc.total_cuotas_credito
    INTO 
        v_nombre_cliente,
        v_cod_credito,
        v_nombre_credito,
        v_total_cuotas_original
    FROM CREDITO_CLIENTE cc
    INNER JOIN CLIENTE cl ON cc.nro_cliente = cl.nro_cliente
    INNER JOIN CREDITO cr ON cc.cod_credito = cr.cod_credito
    WHERE cc.nro_solic_credito = v_nro_solic_credito;
    
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('INFORMACIÓN DEL CRÉDITO:');
    DBMS_OUTPUT.PUT_LINE('--------------------------------------------------');
    DBMS_OUTPUT.PUT_LINE('Cliente: ' || v_nombre_cliente);
    DBMS_OUTPUT.PUT_LINE('Nro. Cliente: ' || v_nro_cliente);
    DBMS_OUTPUT.PUT_LINE('Nro. Solicitud: ' || v_nro_solic_credito);
    DBMS_OUTPUT.PUT_LINE('Tipo Crédito: ' || v_nombre_credito);
    DBMS_OUTPUT.PUT_LINE('Total Cuotas Original: ' || v_total_cuotas_original);
    DBMS_OUTPUT.PUT_LINE('Cuotas a Postergar: ' || v_cant_cuotas_postergar);
    DBMS_OUTPUT.PUT_LINE('');
    
    -- ========================================================================
    -- 4. OBTENER DATOS DE LA ÚLTIMA CUOTA ORIGINAL
    -- ========================================================================
    
    -- Obtener el número, fecha de vencimiento y valor de la última cuota
    SELECT 
        nro_cuota,
        fecha_venc_cuota,
        valor_cuota
    INTO 
        v_ultimo_nro_cuota,
        v_ultima_fecha_venc,
        v_valor_ultima_cuota
    FROM CUOTA_CREDITO_CLIENTE
    WHERE nro_solic_credito = v_nro_solic_credito
    AND nro_cuota = v_total_cuotas_original;
    
    DBMS_OUTPUT.PUT_LINE('ÚLTIMA CUOTA ORIGINAL:');
    DBMS_OUTPUT.PUT_LINE('--------------------------------------------------');
    DBMS_OUTPUT.PUT_LINE('Nro. Cuota: ' || v_ultimo_nro_cuota);
    DBMS_OUTPUT.PUT_LINE('Fecha Vencimiento: ' || TO_CHAR(v_ultima_fecha_venc, 'DD/MM/YYYY'));
    DBMS_OUTPUT.PUT_LINE('Valor Cuota: $' || TO_CHAR(v_valor_ultima_cuota, '999,999,999'));
    DBMS_OUTPUT.PUT_LINE('');
    
    -- ========================================================================
    -- 5. VERIFICAR SI APLICA CONDONACIÓN (MÁS DE 1 CRÉDITO AÑO ANTERIOR)
    -- ========================================================================
    
    DBMS_OUTPUT.PUT_LINE('VERIFICANDO BONIFICACIÓN...');
    DBMS_OUTPUT.PUT_LINE('--------------------------------------------------');
    
    -- Contar cuántos créditos solicitó el cliente el año anterior
    SELECT COUNT(*)
    INTO v_cant_creditos_anio_anterior
    FROM CREDITO_CLIENTE
    WHERE nro_cliente = v_nro_cliente
    AND EXTRACT(YEAR FROM fecha_solic_cred) = v_anio_proceso;
    
    DBMS_OUTPUT.PUT_LINE('Créditos solicitados en ' || v_anio_proceso || ': ' || v_cant_creditos_anio_anterior);
    
    -- Determinar si aplica condonación usando estructura condicional
    IF v_cant_creditos_anio_anterior > 1 THEN
        v_aplica_condonacion := TRUE;
        DBMS_OUTPUT.PUT_LINE('✓ APLICA CONDONACIÓN de última cuota original');
    ELSE
        v_aplica_condonacion := FALSE;
        DBMS_OUTPUT.PUT_LINE('✗ No aplica condonación');
    END IF;
    
    DBMS_OUTPUT.PUT_LINE('');
    
    -- ========================================================================
    -- 6. DETERMINAR TASA DE INTERÉS SEGÚN TIPO DE CRÉDITO
    -- ========================================================================
    
    DBMS_OUTPUT.PUT_LINE('CALCULANDO TASA DE INTERÉS...');
    DBMS_OUTPUT.PUT_LINE('--------------------------------------------------');
    
    -- Usar estructura condicional para determinar la tasa según tipo de crédito
    IF v_cod_credito = 1 THEN
        -- CRÉDITO HIPOTECARIO
        IF v_cant_cuotas_postergar = 1 THEN
            -- 1 cuota sin interés
            v_tasa_interes := 0;
            DBMS_OUTPUT.PUT_LINE('Crédito Hipotecario - 1 cuota');
            DBMS_OUTPUT.PUT_LINE('Tasa de interés: 0% (sin interés)');
        ELSIF v_cant_cuotas_postergar = 2 THEN
            -- 2 cuotas con 0.5% de interés
            v_tasa_interes := 0.005;
            DBMS_OUTPUT.PUT_LINE('Crédito Hipotecario - 2 cuotas');
            DBMS_OUTPUT.PUT_LINE('Tasa de interés: 0.5%');
        ELSE
            DBMS_OUTPUT.PUT_LINE('ERROR: Crédito Hipotecario solo permite 1 o 2 cuotas');
            RETURN;
        END IF;
        
    ELSIF v_cod_credito = 2 THEN
        -- CRÉDITO DE CONSUMO
        IF v_cant_cuotas_postergar = 1 THEN
            -- 1 cuota con 1% de interés
            v_tasa_interes := 0.01;
            DBMS_OUTPUT.PUT_LINE('Crédito de Consumo - 1 cuota');
            DBMS_OUTPUT.PUT_LINE('Tasa de interés: 1%');
        ELSE
            DBMS_OUTPUT.PUT_LINE('ERROR: Crédito de Consumo solo permite 1 cuota');
            RETURN;
        END IF;
        
    ELSIF v_cod_credito = 3 THEN
        -- CRÉDITO AUTOMOTRIZ
        IF v_cant_cuotas_postergar = 1 THEN
            -- 1 cuota con 2% de interés
            v_tasa_interes := 0.02;
            DBMS_OUTPUT.PUT_LINE('Crédito Automotriz - 1 cuota');
            DBMS_OUTPUT.PUT_LINE('Tasa de interés: 2%');
        ELSE
            DBMS_OUTPUT.PUT_LINE('ERROR: Crédito Automotriz solo permite 1 cuota');
            RETURN;
        END IF;
        
    ELSE
        DBMS_OUTPUT.PUT_LINE('ERROR: Tipo de crédito no válido para postergación');
        RETURN;
    END IF;
    
    DBMS_OUTPUT.PUT_LINE('');
    
    -- ========================================================================
    -- 7. CONDONAR ÚLTIMA CUOTA ORIGINAL (SI APLICA)
    -- ========================================================================
    
    IF v_aplica_condonacion THEN
        DBMS_OUTPUT.PUT_LINE('APLICANDO CONDONACIÓN...');
        DBMS_OUTPUT.PUT_LINE('--------------------------------------------------');
        
        -- Actualizar la última cuota original como pagada
        UPDATE CUOTA_CREDITO_CLIENTE
        SET fecha_pago_cuota = fecha_venc_cuota,
            monto_pagado = valor_cuota,
            saldo_por_pagar = 0
        WHERE nro_solic_credito = v_nro_solic_credito
        AND nro_cuota = v_ultimo_nro_cuota;
        
        DBMS_OUTPUT.PUT_LINE('✓ Última cuota original (cuota ' || v_ultimo_nro_cuota || ') CONDONADA');
        DBMS_OUTPUT.PUT_LINE('  Fecha de pago: ' || TO_CHAR(v_ultima_fecha_venc, 'DD/MM/YYYY'));
        DBMS_OUTPUT.PUT_LINE('  Monto pagado: $' || TO_CHAR(v_valor_ultima_cuota, '999,999,999'));
        DBMS_OUTPUT.PUT_LINE('');
    END IF;
    
    -- ========================================================================
    -- 8. GENERAR NUEVAS CUOTAS POSTERGADAS
    -- ========================================================================
    
    DBMS_OUTPUT.PUT_LINE('GENERANDO NUEVAS CUOTAS...');
    DBMS_OUTPUT.PUT_LINE('--------------------------------------------------');
    
    -- Inicializar variables para el loop
    v_nuevo_nro_cuota := v_ultimo_nro_cuota;
    v_nueva_fecha_venc := v_ultima_fecha_venc;
    
    -- Loop para crear cada cuota postergada
    FOR v_contador IN 1..v_cant_cuotas_postergar LOOP
        
        -- Calcular número de la nueva cuota (correlativo)
        v_nuevo_nro_cuota := v_nuevo_nro_cuota + 1;
        
        -- Calcular fecha de vencimiento (mes siguiente)
        v_nueva_fecha_venc := ADD_MONTHS(v_nueva_fecha_venc, 1);
        
        -- Calcular valor de la nueva cuota con la tasa de interés
        v_valor_nueva_cuota := ROUND(v_valor_ultima_cuota + (v_valor_ultima_cuota * v_tasa_interes));
        
        -- Insertar la nueva cuota en la tabla
        INSERT INTO CUOTA_CREDITO_CLIENTE (
            nro_solic_credito,
            nro_cuota,
            fecha_venc_cuota,
            valor_cuota,
            fecha_pago_cuota,
            monto_pagado,
            saldo_por_pagar,
            cod_forma_pago
        ) VALUES (
            v_nro_solic_credito,
            v_nuevo_nro_cuota,
            v_nueva_fecha_venc,
            v_valor_nueva_cuota,
            NULL,
            NULL,
            NULL,
            NULL
        );
        
        DBMS_OUTPUT.PUT_LINE('✓ Cuota ' || v_nuevo_nro_cuota || ' creada:');
        DBMS_OUTPUT.PUT_LINE('  Fecha vencimiento: ' || TO_CHAR(v_nueva_fecha_venc, 'DD/MM/YYYY'));
        DBMS_OUTPUT.PUT_LINE('  Valor cuota: $' || TO_CHAR(v_valor_nueva_cuota, '999,999,999'));
        DBMS_OUTPUT.PUT_LINE('');
        
    END LOOP;
    
    -- ========================================================================
    -- 9. ACTUALIZAR TOTAL DE CUOTAS EN CREDITO_CLIENTE
    -- ========================================================================
    
    DBMS_OUTPUT.PUT_LINE('ACTUALIZANDO INFORMACIÓN DEL CRÉDITO...');
    DBMS_OUTPUT.PUT_LINE('--------------------------------------------------');
    
    -- Actualizar el total de cuotas del crédito
    UPDATE CREDITO_CLIENTE
    SET total_cuotas_credito = total_cuotas_credito + v_cant_cuotas_postergar
    WHERE nro_solic_credito = v_nro_solic_credito;
    
    DBMS_OUTPUT.PUT_LINE('✓ Total de cuotas actualizado');
    DBMS_OUTPUT.PUT_LINE('  Cuotas originales: ' || v_total_cuotas_original);
    DBMS_OUTPUT.PUT_LINE('  Cuotas postergadas: +' || v_cant_cuotas_postergar);
    DBMS_OUTPUT.PUT_LINE('  Total nuevo: ' || (v_total_cuotas_original + v_cant_cuotas_postergar));
    DBMS_OUTPUT.PUT_LINE('');
    
    -- ========================================================================
    -- 10. CONFIRMAR TRANSACCIÓN
    -- ========================================================================
    
    COMMIT;
    
    DBMS_OUTPUT.PUT_LINE('================================================================================');
    DBMS_OUTPUT.PUT_LINE('PROCESO COMPLETADO EXITOSAMENTE');
    DBMS_OUTPUT.PUT_LINE('================================================================================');
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('RESUMEN:');
    DBMS_OUTPUT.PUT_LINE('  Cliente: ' || v_nombre_cliente);
    DBMS_OUTPUT.PUT_LINE('  Crédito: ' || v_nro_solic_credito);
    DBMS_OUTPUT.PUT_LINE('  Cuotas postergadas: ' || v_cant_cuotas_postergar);
    IF v_aplica_condonacion THEN
        DBMS_OUTPUT.PUT_LINE('  Condonación: SÍ');
    ELSE
        DBMS_OUTPUT.PUT_LINE('  Condonación: NO');
    END IF;
    DBMS_OUTPUT.PUT_LINE('  Total cuotas nuevo: ' || (v_total_cuotas_original + v_cant_cuotas_postergar));
    DBMS_OUTPUT.PUT_LINE('================================================================================');
    
EXCEPTION
    -- ========================================================================
    -- MANEJO DE ERRORES
    -- ========================================================================
    
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('ERROR: No se encontraron datos');
        DBMS_OUTPUT.PUT_LINE('Verifique que el crédito ' || v_nro_solic_credito || 
                            ' existe para el cliente ' || v_nro_cliente);
        ROLLBACK;
        
    WHEN TOO_MANY_ROWS THEN
        DBMS_OUTPUT.PUT_LINE('ERROR: Se encontraron múltiples registros');
        ROLLBACK;
        
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('ERROR INESPERADO: ' || SQLERRM);
        DBMS_OUTPUT.PUT_LINE('Código de error: ' || SQLCODE);
        ROLLBACK;
        
END;
/

/*
================================================================================
INSTRUCCIONES DE EJECUCIÓN - CASO 2
================================================================================

CLIENTES DE PRUEBA:
--------------------------------------------------
1. SEBASTIAN PATRICIO QUINTANA BERRIOS
   Nro. Cliente: 5
   Nro. Solicitud: 2001 (Hipotecario)
   Cuotas a postergar: 2
   
2. KAREN SOFIA PRADENAS MANDIOLA
   Nro. Cliente: 67
   Nro. Solicitud: 3004 (Automotriz)
   Cuotas a postergar: 1
   
3. JULIAN PAUL ARRIAGADA LUJAN
   Nro. Cliente: 13
   Nro. Solicitud: 2004 (Consumo)
   Cuotas a postergar: 1

CONSULTA PARA VERIFICAR RESULTADOS:
--------------------------------------------------
-- Ver cuotas del crédito 2001
SELECT * FROM CUOTA_CREDITO_CLIENTE 
WHERE nro_solic_credito = 2001 
ORDER BY nro_cuota;

-- Ver cuotas del crédito 3004
SELECT * FROM CUOTA_CREDITO_CLIENTE 
WHERE nro_solic_credito = 3004 
ORDER BY nro_cuota;

-- Ver cuotas del crédito 2004
SELECT * FROM CUOTA_CREDITO_CLIENTE 
WHERE nro_solic_credito = 2004 
ORDER BY nro_cuota;

*/