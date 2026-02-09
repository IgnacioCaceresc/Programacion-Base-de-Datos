--Tuve que updatear la tabla por problemas con el tilde en Súper--

UPDATE TIPO_TRANSACCION_TARJETA
SET nombre_tptran_tarjeta = 'Súper Avance en Efectivo'
WHERE cod_tptran_tarjeta = 103;

COMMIT;

SET SERVEROUTPUT OFF;

DECLARE
    -- Variables --
    v_anio_proceso      NUMBER;
    v_porcentaje_sbif   NUMBER;
    v_monto_aporte      NUMBER;
    
    -- Acumuladores --
    v_suma_monto_total  NUMBER;
    v_suma_aporte_total NUMBER;

    -- CURSOR 1 --
    CURSOR c_resumen IS
        SELECT DISTINCT 
            TO_CHAR(ttc.fecha_transaccion, 'MMYYYY') AS mes_anno,
            ttt.nombre_tptran_tarjeta,
            ttt.cod_tptran_tarjeta
        FROM TRANSACCION_TARJETA_CLIENTE ttc
        JOIN TIPO_TRANSACCION_TARJETA ttt ON ttc.cod_tptran_tarjeta = ttt.cod_tptran_tarjeta
        WHERE EXTRACT(YEAR FROM ttc.fecha_transaccion) = EXTRACT(YEAR FROM SYSDATE)
          AND ttt.nombre_tptran_tarjeta LIKE '%Avance%'
        ORDER BY 1 ASC, 2 ASC;

    reg_res c_resumen%ROWTYPE;

    -- CURSOR 2 --
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
    -- Limpieza de tablas --
    EXECUTE IMMEDIATE 'TRUNCATE TABLE DETALLE_APORTE_SBIF';
    EXECUTE IMMEDIATE 'TRUNCATE TABLE RESUMEN_APORTE_SBIF';

    v_anio_proceso := EXTRACT(YEAR FROM SYSDATE);
    DBMS_OUTPUT.PUT_LINE('Procesando año: ' || v_anio_proceso);

    -- Procesar Cursor Resumen --
    OPEN c_resumen;
    LOOP
        FETCH c_resumen INTO reg_res;
        EXIT WHEN c_resumen%NOTFOUND;

        v_suma_monto_total := 0;
        v_suma_aporte_total := 0;

        -- Procesar Cursor Detalle --
        OPEN c_detalle(reg_res.mes_anno, reg_res.cod_tptran_tarjeta);
        LOOP
            FETCH c_detalle INTO reg_det;
            EXIT WHEN c_detalle%NOTFOUND;

            -- Obtener porcentaje según tramo --
            v_porcentaje_sbif := 0;
            BEGIN
                SELECT porc_aporte_sbif 
                INTO v_porcentaje_sbif
                FROM TRAMO_APORTE_SBIF
                WHERE reg_det.monto_total_transaccion BETWEEN tramo_inf_av_sav AND tramo_sup_av_sav;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN v_porcentaje_sbif := 0;
            END;

            -- Calcular aporte --
            v_monto_aporte := ROUND(reg_det.monto_total_transaccion * (v_porcentaje_sbif / 100));

            -- Insertar Detalle -- 
            INSERT INTO DETALLE_APORTE_SBIF (
                numrun, dvrun, nro_tarjeta, nro_transaccion,
                fecha_transaccion, tipo_transaccion,
                monto_transaccion, 
                aporte_sbif
            ) VALUES (
                reg_det.numrun, reg_det.dvrun, reg_det.nro_tarjeta,
                reg_det.nro_transaccion, reg_det.fecha_transaccion,
                reg_det.nombre_tptran_tarjeta,
                reg_det.monto_total_transaccion, 
                v_monto_aporte
            );

            -- Acumular --
            v_suma_monto_total := v_suma_monto_total + reg_det.monto_total_transaccion;
            v_suma_aporte_total := v_suma_aporte_total + v_monto_aporte;

        END LOOP;
        CLOSE c_detalle;

        -- Insertar Resumen --
        INSERT INTO RESUMEN_APORTE_SBIF (
            mes_anno, tipo_transaccion, 
            monto_total_transacciones, aporte_total_abif
        ) VALUES (
            reg_res.mes_anno, reg_res.nombre_tptran_tarjeta,
            v_suma_monto_total, v_suma_aporte_total
        );

    END LOOP;
    CLOSE c_resumen;

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Proceso finalizado correctamente.');

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
END;
/

-- Consulta N°1 --
SELECT * FROM DETALLE_APORTE_SBIF 
ORDER BY fecha_transaccion ASC, numrun ASC;
-- Consulta N°2 --
SELECT * FROM RESUMEN_APORTE_SBIF 
ORDER BY mes_anno ASC, tipo_transaccion ASC;
