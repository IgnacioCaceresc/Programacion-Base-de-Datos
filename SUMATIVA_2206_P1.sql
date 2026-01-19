-- Limpiar tabla destino para permitir múltiples ejecuciones
TRUNCATE TABLE usuario_clave;

-- Habilitar salida por consola
SET SERVEROUTPUT OFF;

-- Declaración de variable BIND para fecha de proceso
VARIABLE b_fecha_proceso VARCHAR2(8);
EXEC :b_fecha_proceso := TO_CHAR(SYSDATE, 'DDMMYYYY');

/*
================================================================================
BLOQUE PL/SQL ANÓNIMO - GENERACIÓN DE CREDENCIALES
================================================================================
*/
DECLARE
    -- =========================================================================
    -- DECLARACIÓN DE VARIABLES
    -- =========================================================================
    
    -- Variable para convertir la variable BIND 
    v_fecha_proceso     DATE;
    
    -- Variables de control de iteración 
    v_id_empleado       empleado.id_emp%TYPE := 100;
    v_id_final          empleado.id_emp%TYPE := 320;
    v_contador_registros NUMBER := 0;
    
    -- Variables para datos del empleado 
    v_numrun            empleado.numrun_emp%TYPE;
    v_dvrun             empleado.dvrun_emp%TYPE;
    v_primer_nombre     empleado.pnombre_emp%TYPE;
    v_segundo_nombre    empleado.snombre_emp%TYPE;
    v_apellido_paterno  empleado.appaterno_emp%TYPE;
    v_apellido_materno  empleado.apmaterno_emp%TYPE;
    v_sueldo_base       empleado.sueldo_base%TYPE;
    v_fecha_nacimiento  empleado.fecha_nac%TYPE;
    v_fecha_contrato    empleado.fecha_contrato%TYPE;
    v_id_estado_civil   empleado.id_estado_civil%TYPE;
    v_nombre_estado_civil estado_civil.nombre_estado_civil%TYPE;
    
    -- Variables para construcción del nombre de usuario
    v_letra_estado      CHAR(1);
    v_tres_letras_nombre VARCHAR2(3);
    v_largo_nombre      NUMBER(2);
    v_ultimo_dig_sueldo CHAR(1);
    v_anios_trabajados  NUMBER(3);
    v_marca_antiguedad  CHAR(1);
    v_nombre_usuario    VARCHAR2(20);
    
    -- Variables para construcción de la clave
    v_tercer_digito_run CHAR(1);
    v_anio_nac_mas_dos  NUMBER(4);
    v_ultimos_3_dig_sueldo NUMBER(3);
    v_dos_letras_apellido VARCHAR2(2);
    v_mes_anio_bd       VARCHAR2(6);
    v_clave_usuario     VARCHAR2(20);
    
    -- Variables auxiliares
    v_run_texto         VARCHAR2(10);
    v_nombre_completo   VARCHAR2(100);
    v_largo_apellido    NUMBER(2);
    
BEGIN

    -- Convertir variable BIND VARCHAR2 a DATE
    v_fecha_proceso := TO_DATE(:b_fecha_proceso, 'DDMMYYYY');
    
    DBMS_OUTPUT.PUT_LINE('========================================');
    DBMS_OUTPUT.PUT_LINE('GENERACIÓN DE CREDENCIALES - TRUCK RENTAL');
    DBMS_OUTPUT.PUT_LINE('Fecha: ' || TO_CHAR(v_fecha_proceso, 'DD/MM/YYYY'));
    DBMS_OUTPUT.PUT_LINE('========================================');
    DBMS_OUTPUT.PUT_LINE(' ');
    
    -- Ciclo principal: procesar empleados desde ID 100 hasta 320
    WHILE v_id_empleado <= v_id_final LOOP
        
        BEGIN
            -- =================================================================
            -- Obtener datos del empleado
            -- =================================================================
            SELECT 
                e.numrun_emp,
                e.dvrun_emp,
                e.pnombre_emp,
                e.snombre_emp,
                e.appaterno_emp,
                e.apmaterno_emp,
                e.sueldo_base,
                e.fecha_nac,
                e.fecha_contrato,
                e.id_estado_civil,
                ec.nombre_estado_civil
            INTO 
                v_numrun,
                v_dvrun,
                v_primer_nombre,
                v_segundo_nombre,
                v_apellido_paterno,
                v_apellido_materno,
                v_sueldo_base,
                v_fecha_nacimiento,
                v_fecha_contrato,
                v_id_estado_civil,
                v_nombre_estado_civil
            FROM empleado e
            INNER JOIN estado_civil ec ON e.id_estado_civil = ec.id_estado_civil
            WHERE e.id_emp = v_id_empleado;
            
            -- =================================================================
            -- CONSTRUCCIÓN DEL NOMBRE DE USUARIO
            -- =================================================================
            
            -- Componente a) Primera letra del estado civil en minúscula
            v_letra_estado := LOWER(SUBSTR(v_nombre_estado_civil, 1, 1));
            
            -- Componente b) Tres primeras letras del primer nombre
            v_tres_letras_nombre := SUBSTR(v_primer_nombre, 1, 3);
            
            -- Componente c) Largo del primer nombre
            v_largo_nombre := LENGTH(v_primer_nombre);
            
            -- Componente e) Último dígito del sueldo base
            v_ultimo_dig_sueldo := SUBSTR(TO_CHAR(v_sueldo_base), -1, 1);
            
            -- Calcular años trabajados
            -- Calcula la antigüedad del empleado usando v_fecha_proceso
            -- y redondeando a enteros con TRUNC según requerimiento
            v_anios_trabajados := TRUNC(MONTHS_BETWEEN(v_fecha_proceso, v_fecha_contrato) / 12);
            
            -- Determinar marca de antigüedad
            -- Estructura condicional para asignar X
            IF v_anios_trabajados < 10 THEN
                v_marca_antiguedad := 'X';
            ELSE
                v_marca_antiguedad := '';
            END IF;
            
            -- Concatenar componentes del nombre de usuario
            v_nombre_usuario := v_letra_estado ||           -- a) Letra estado civil
                                v_tres_letras_nombre ||     -- b) Tres letras nombre
                                v_largo_nombre ||           -- c) Largo nombre
                                '*' ||                      -- d) Asterisco
                                v_ultimo_dig_sueldo ||      -- e) Último dígito sueldo
                                v_dvrun ||                  -- f) Dígito verificador
                                v_anios_trabajados ||       -- g) Años trabajados
                                v_marca_antiguedad;         -- h) Marca X si < 10 años
            
            -- =================================================================
            -- CONSTRUCCIÓN DE LA CLAVE
            -- =================================================================
            
            -- Componente a) Tercer dígito del RUN
            v_run_texto := TO_CHAR(v_numrun);
            v_tercer_digito_run := SUBSTR(v_run_texto, 3, 1);
            
            -- Componente b) Año de nacimiento aumentado en 2
            v_anio_nac_mas_dos := EXTRACT(YEAR FROM v_fecha_nacimiento) + 2;
            
            -- Calcular últimos 3 dígitos del sueldo - 1
            v_ultimos_3_dig_sueldo := MOD(v_sueldo_base, 1000) - 1;
            
            -- Ajuste si el resultado es negativo 
            IF v_ultimos_3_dig_sueldo < 0 THEN
                v_ultimos_3_dig_sueldo := 999;
            END IF;
            
            -- Extraer dos letras del apellido según estado civil
            -- según el estado civil del empleado
            v_largo_apellido := LENGTH(v_apellido_paterno);
            
            IF v_id_estado_civil IN (10, 60) THEN
                -- Casado (10) o Acuerdo de Unión Civil (60): dos primeras letras
                v_dos_letras_apellido := LOWER(SUBSTR(v_apellido_paterno, 1, 2));
                
            ELSIF v_id_estado_civil IN (20, 30) THEN
                -- Divorciado (20) o Soltero (30): primera y última letra
                v_dos_letras_apellido := LOWER(SUBSTR(v_apellido_paterno, 1, 1) || 
                                                SUBSTR(v_apellido_paterno, -1, 1));
                
            ELSIF v_id_estado_civil = 40 THEN
                -- Viudo (40): antepenúltima y penúltima letra
                v_dos_letras_apellido := LOWER(SUBSTR(v_apellido_paterno, -3, 2));
                
            ELSIF v_id_estado_civil = 50 THEN
                -- Separado (50): dos últimas letras
                v_dos_letras_apellido := LOWER(SUBSTR(v_apellido_paterno, -2, 2));
            END IF;
            
            -- Componente f) Mes y año de la base de datos (formato MMYYYY)
            v_mes_anio_bd := TO_CHAR(v_fecha_proceso, 'MMYYYY');
            
            -- Concatenar componentes de la clave
            v_clave_usuario := v_tercer_digito_run ||                   -- a) Tercer dígito RUN
                               v_anio_nac_mas_dos ||                    -- b) Año nac + 2
                               LPAD(v_ultimos_3_dig_sueldo, 3, '0') || -- c) Últimos 3 dígitos sueldo - 1
                               v_dos_letras_apellido ||                 -- d) Dos letras apellido
                               v_id_empleado ||                         -- e) ID empleado
                               v_mes_anio_bd;                           -- f) Mes-año BD
            
            -- Construir nombre completo del empleado
            v_nombre_completo := v_primer_nombre || ' ' || v_segundo_nombre || ' ' || v_apellido_paterno || ' ' || v_apellido_materno;
            
            -- =================================================================
            -- Insertar credenciales en tabla destino
            -- =================================================================
            INSERT INTO usuario_clave (
                id_emp,
                numrun_emp,
                dvrun_emp,
                nombre_empleado,
                nombre_usuario,
                clave_usuario
            ) VALUES (
                v_id_empleado,
                v_numrun,
                v_dvrun,
                v_nombre_completo,
                v_nombre_usuario,
                v_clave_usuario
            );
            
            -- Incrementar contador de registros procesados exitosamente
            v_contador_registros := v_contador_registros + 1;
            
            -- Mostrar progreso
            DBMS_OUTPUT.PUT_LINE('✓ ID ' || v_id_empleado || ': ' || v_nombre_completo || ' - ' || v_nombre_usuario);
            
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                -- Si no existe empleado con este ID, continuar con el siguiente
                NULL;
                
            WHEN OTHERS THEN
                -- Capturar cualquier otro error y continuar procesando
                DBMS_OUTPUT.PUT_LINE('✗ Error en empleado ' || v_id_empleado || ': ' || SQLERRM);
        END;
        
        -- Incrementar ID para siguiente iteración (incremento de 10)
        v_id_empleado := v_id_empleado + 10;
        
    END LOOP;
    
    -- =========================================================================
    -- CONFIRMACIÓN DE TRANSACCIÓN
    -- Se confirma solo si se procesaron todos los empleados esperados
    -- =========================================================================
    
    DBMS_OUTPUT.PUT_LINE(' ');
    DBMS_OUTPUT.PUT_LINE('========================================');
    DBMS_OUTPUT.PUT_LINE('RESUMEN DE PROCESO');
    DBMS_OUTPUT.PUT_LINE('========================================');
    DBMS_OUTPUT.PUT_LINE('Empleados procesados: ' || v_contador_registros);
    DBMS_OUTPUT.PUT_LINE('Empleados esperados: ' || ((v_id_final - 100) / 10 + 1));
    
    -- Calcular total esperado: (320-100)/10 + 1 = 23 empleados
    IF v_contador_registros = ((v_id_final - 100) / 10 + 1) THEN
        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Estado: EXITOSO');
        DBMS_OUTPUT.PUT_LINE('Acción: Transacción CONFIRMADA');
    ELSE
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Estado: ✗ ERROR');
        DBMS_OUTPUT.PUT_LINE('Acción: Transacción REVERTIDA (ROLLBACK)');
    END IF;
    
    DBMS_OUTPUT.PUT_LINE('========================================');
    
EXCEPTION
    WHEN OTHERS THEN
        -- Manejo de errores críticos a nivel de bloque
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE(' ');
        DBMS_OUTPUT.PUT_LINE('========================================');
        DBMS_OUTPUT.PUT_LINE('✗ ERROR CRÍTICO EN EL PROCESO');
        DBMS_OUTPUT.PUT_LINE('Mensaje: ' || SQLERRM);
        DBMS_OUTPUT.PUT_LINE('Acción: Transacción REVERTIDA (ROLLBACK)');
        DBMS_OUTPUT.PUT_LINE('========================================');
        RAISE;
END;
/


-- Mostrar todos los usuarios generados ordenados por ID
SELECT 
    id_emp AS "ID_EMP",
    numrun_emp AS "NUMRUN_EMP",
    dvrun_emp AS "DVRUN_EMP",
    nombre_empleado AS "NOMBRE_EMPLEADO",
    nombre_usuario AS "NOMBRE_USUARIO",
    clave_usuario AS "CLAVE_USUARIO"
FROM usuario_clave
ORDER BY id_emp;

-- Contar total de credenciales generadas
SELECT COUNT(*) AS "TOTAL_CREDENCIALES_GENERADAS"
FROM usuario_clave;
