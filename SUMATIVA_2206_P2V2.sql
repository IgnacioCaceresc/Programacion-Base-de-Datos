--Me quedó la duda con las imagenes del archivo word ya que si calzábamos los datos con los del año 2026, se podía replicar tal cual los datos e imagenes que en el archivo se mostraban, pero puesto que en la actividad se detalla que la idea es que analice los datos del año anterior a cuando se ejecuta el script, los datos difieren totalmente de los expuestos en las imágenes. Por este motivo el trabajo actual lo hice con el año anterior con respecto a la fecha en que se ejecuta el código, declarado con el :b_anio_proceso := EXTRACT(YEAR FROM SYSDATE) - 1 --

SET SERVEROUTPUT OFF;

VARIABLE b_anio_proceso NUMBER;

-- Busqueda de datos del año anterior hecha la consulta --
BEGIN
    :b_anio_proceso := EXTRACT(YEAR FROM SYSDATE) - 1; 
END;
/

PRINT b_anio_proceso;


-- Bloque principal --
DECLARE

    -- VARRAY --
    TYPE t_arr_tipos IS VARRAY(2) OF VARCHAR2(100);
    v_tipos_validos t_arr_tipos := t_arr_tipos('Avance', 'Súper Avance');

    -- EXCEPCIONES --
    e_sin_registros EXCEPTION;
    
    e_valor_excesivo EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_valor_excesivo, -01438);

    -- Variables Generales --
    v_anio              NUMBER;
    v_porcentaje_sbif   NUMBER;
    v_monto_aporte      NUMBER;
    
    -- CONTADORES --
    v_total_registros_esperados NUMBER := 0;
    v_total_procesados          NUMBER := 0;

    -- Acumuladores --
    v_suma_monto_total  NUMBER;
    v_suma_aporte_total NUMBER;

    -- CURSORES EXPLÍCITOS --

    -- CURSOR 1: RESUMEN --
    CURSOR c_resumen IS
        SELECT DISTINCT 
            TO_CHAR(ttc.fecha_transaccion, 'MMYYYY') AS mes_anno,
            ttt.nombre_tptran_tarjeta,
            ttt.cod_tptran_tarjeta
        FROM TRANSACCION_TARJETA_CLIENTE ttc
        JOIN TIPO_TRANSACCION_TARJETA ttt ON ttc.cod_tptran_tarjeta = ttt.cod_tptran_tarjeta
        WHERE EXTRACT(YEAR FROM ttc.fecha_transaccion) = v_anio
          AND ttt.nombre_tptran_tarjeta LIKE '%Avance%'
        ORDER BY 1 ASC, 2 ASC;

    -- REGISTRO PL/SQL --
    reg_res c_resumen%ROWTYPE;

    -- CURSOR 2: DETALLE --
    CURSOR c_detalle (p_mes VARCHAR2, p_cod_tptran NUMBER) IS
        SELECT 
            c.numrun, 
            c.dvrun, 
            tc.nro_tarjeta, 
            ttc.nro_transaccion, 
            ttc.fecha_transaccion,
            ttt.nombre_tptran_tarjeta, 
            ttc.monto_total_transaccion
        FROM TRANSACCION_TARJETA_CLIENTE ttc
        JOIN TARJETA_CLIENTE tc ON ttc.nro_tarjeta = tc.nro_tarjeta
        JOIN CLIENTE c ON tc.numrun = c.numrun
        JOIN TIPO_TRANSACCION_TARJETA ttt ON ttc.cod_tptran_tarjeta = ttt.cod_tptran_tarjeta
        WHERE TO_CHAR(ttc.fecha_transaccion, 'MMYYYY') = p_mes
          AND ttc.cod_tptran_tarjeta = p_cod_tptran
        ORDER BY ttc.fecha_transaccion ASC, c.numrun ASC;

    reg_det c_detalle%ROWTYPE;

BEGIN
    -- Variable Bind --
    v_anio := :b_anio_proceso;

    -- TRUNCAR TABLAS --
    EXECUTE IMMEDIATE 'TRUNCATE TABLE DETALLE_APORTE_SBIF';
    EXECUTE IMMEDIATE 'TRUNCATE TABLE RESUMEN_APORTE_SBIF';

    -- Validación inicial de cantidad de registros --
    SELECT COUNT(*) INTO v_total_registros_esperados
    FROM TRANSACCION_TARJETA_CLIENTE ttc
    JOIN TIPO_TRANSACCION_TARJETA ttt ON ttc.cod_tptran_tarjeta = ttt.cod_tptran_tarjeta
    WHERE EXTRACT(YEAR FROM ttc.fecha_transaccion) = v_anio
      AND ttt.nombre_tptran_tarjeta LIKE '%Avance%';

    IF v_total_registros_esperados = 0 THEN
        RAISE e_sin_registros;
    END IF;

    DBMS_OUTPUT.PUT_LINE('Procesando año: ' || v_anio || '. Registros detectados: ' || v_total_registros_esperados);

    -- REQUERIMIENTO A: Procesar los avances --
    OPEN c_resumen;
    LOOP
        FETCH c_resumen INTO reg_res;
        EXIT WHEN c_resumen%NOTFOUND;

        v_suma_monto_total := 0;
        v_suma_aporte_total := 0;

        OPEN c_detalle(reg_res.mes_anno, reg_res.cod_tptran_tarjeta);
        LOOP
            FETCH c_detalle INTO reg_det;
            EXIT WHEN c_detalle%NOTFOUND;

            -- Cálculo --
            v_porcentaje_sbif := 0;
            
            BEGIN
                SELECT porc_aporte_sbif 
                INTO v_porcentaje_sbif
                FROM TRAMO_APORTE_SBIF
                WHERE reg_det.monto_total_transaccion BETWEEN tramo_inf_av_sav AND tramo_sup_av_sav;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN v_porcentaje_sbif := 0;
            END;

            v_monto_aporte := ROUND(reg_det.monto_total_transaccion * (v_porcentaje_sbif / 100));

            -- INSERTAR DETALLE --
            INSERT INTO DETALLE_APORTE_SBIF (
                numrun, dvrun, nro_tarjeta, nro_transaccion,
                fecha_transaccion, tipo_transaccion,
                monto_transaccion, aporte_sbif
            ) VALUES (
                reg_det.numrun, reg_det.dvrun, reg_det.nro_tarjeta,
                reg_det.nro_transaccion, reg_det.fecha_transaccion,
                reg_det.nombre_tptran_tarjeta,
                reg_det.monto_total_transaccion, v_monto_aporte
            );

            -- Actualizar contadores --
            v_suma_monto_total := v_suma_monto_total + reg_det.monto_total_transaccion;
            v_suma_aporte_total := v_suma_aporte_total + v_monto_aporte;
            v_total_procesados := v_total_procesados + 1;

        END LOOP;
        CLOSE c_detalle;

        -- INSERTAR RESUMEN --
        INSERT INTO RESUMEN_APORTE_SBIF (
            mes_anno, tipo_transaccion, 
            monto_total_transacciones, aporte_total_abif
        ) VALUES (
            reg_res.mes_anno, reg_res.nombre_tptran_tarjeta,
            v_suma_monto_total, v_suma_aporte_total
        );

    END LOOP;
    CLOSE c_resumen;

    -- Confirmación --
    IF v_total_procesados = v_total_registros_esperados THEN
        COMMIT;
        DBMS_OUTPUT.PUT_LINE('ÉXITO: Se procesaron ' || v_total_procesados || ' registros del año ' || v_anio);
    ELSE
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('ERROR: Discrepancia en registros.');
    END IF;

EXCEPTION
    WHEN e_sin_registros THEN
        DBMS_OUTPUT.PUT_LINE('AVISO: No se encontraron transacciones para el año ' || v_anio);
        DBMS_OUTPUT.PUT_LINE('Consejo: Revisa si tus datos de prueba están en el año actual o el anterior.');
    
    WHEN e_valor_excesivo THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Error: Valor numérico demasiado grande.');
        
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Error General: ' || SQLERRM);
END;
/

-- TABLA DETALLE_APORTE_SBIF --
SELECT * FROM DETALLE_APORTE_SBIF 
ORDER BY fecha_transaccion ASC, numrun ASC;
-- TABLA RESUMEN_APORTE_SBIF --
SELECT * FROM RESUMEN_APORTE_SBIF 
ORDER BY mes_anno ASC, tipo_transaccion ASC;



