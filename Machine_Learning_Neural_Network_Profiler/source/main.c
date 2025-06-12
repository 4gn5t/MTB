/******************************************************************************
* File Name:   main.c
*
* Description: This is the source code for the Neural Network Profiler Example
*              for ModusToolbox.
*
* Related Document: See README.md
*
*
*******************************************************************************
* Copyright 2021-2024, Cypress Semiconductor Corporation (an Infineon company) or
* an affiliate of Cypress Semiconductor Corporation.  All rights reserved.
*
* This software, including source code, documentation and related
* materials ("Software") is owned by Cypress Semiconductor Corporation
* or one of its affiliates ("Cypress") and is protected by and subject to
* worldwide patent protection (United States and foreign),
* United States copyright laws and international treaty provisions.
* Therefore, you may use this Software only as provided in the license
* agreement accompanying the software package from which you
* obtained this Software ("EULA").
* If no EULA applies, Cypress hereby grants you a personal, non-exclusive,
* non-transferable license to copy, modify, and compile the Software
* source code solely for use in connection with Cypress's
* integrated circuit products.  Any reproduction, modification, translation,
* compilation, or representation of this Software except as specified
* above is prohibited without the express written permission of Cypress.
*
* Disclaimer: THIS SOFTWARE IS PROVIDED AS-IS, WITH NO WARRANTY OF ANY KIND,
* EXPRESS OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, NONINFRINGEMENT, IMPLIED
* WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. Cypress
* reserves the right to make changes to the Software without notice. Cypress
* does not assume any liability arising out of the application or use of the
* Software or any product or circuit described in the Software. Cypress does
* not authorize its products for use in any products where a malfunction or
* failure of the Cypress product may reasonably be expected to result in
* significant property damage, injury or death ("High Risk Product"). By
* including Cypress's product in a High Risk Product, the manufacturer
* of such system or application assumes all risk of such use and in doing
* so agrees to indemnify Cypress against all liability.
*******************************************************************************/

#include "cy_pdl.h"
#include "cyhal.h"
#include "cybsp.h"
#include "cy_retarget_io.h"

#include "elapsed_timer.h"
#include "mtb_ml_stream.h"
#include "ml_local_regression.h"

#include "string.h"
#include "mtb_ml_stream_impl.h"

#include MTB_ML_INCLUDE_MODEL_FILE(MODEL_NAME)

/*******************************************************************************
* Macros
********************************************************************************/
#define USE_STREAM_DATA             0u
#define USE_LOCAL_DATA              1u

/* Choose the source of regression data. Options:
 * - USE_STREAM_DATA
 * - USE_LOCAL_DATA */ 
#define REGRESSION_DATA_SOURCE      USE_LOCAL_DATA

/* Choose which profiling to enable. Options: 
 *  MTB_ML_PROFILE_DISABLE
 *  MTB_ML_PROFILE_ENABLE_MODEL
 *  MTB_ML_PROFILE_ENABLE_LAYER
 *  MTB_ML_PROFILE_ENABLE_MODEL_PER_FRAME
 *  MTB_ML_PROFILE_ENABLE_LAYER_PER_FRAME
 *  MTB_ML_LOG_ENABLE_MODEL_LOG */
#define PROFILE_CONFIGURATION       MTB_ML_PROFILE_ENABLE_MODEL

/*******************************************************************************
* Function Prototypes
********************************************************************************/

/*******************************************************************************
* Global Variables
********************************************************************************/
static char uart_buffer[64];
static uint8_t buffer_index = 0;
static mtb_ml_model_t *model_object = NULL;

/*******************************************************************************
* Function Name: main
********************************************************************************
* Summary:
* This is the main function for CM4 CPU. It does...
*    1. Initializes the BSP.
*    2. Prints welcome message
*    3. Initialize the regression unit - stream or local
*    4. Run the regression
*
* Parameters:
*  void
*
* Return:
*  int
*
*******************************************************************************/
int main(void)
{
    cy_rslt_t result;

    /* Initialize the device and board peripherals */
    result = cybsp_init() ;
    if (result != CY_RSLT_SUCCESS)
    {
        CY_ASSERT(0);
    }

    /* Enable global interrupts */
    __enable_irq();

    /* Initialize retarget-io to use the debug UART port */
#if REGRESSION_DATA_SOURCE == USE_LOCAL_DATA
    cy_retarget_io_init(CYBSP_DEBUG_UART_TX, CYBSP_DEBUG_UART_RX, CY_RETARGET_IO_BAUDRATE);
#else
    /* Set the baudrate provided by the ML-Middleware (based on host OS) */
    cy_retarget_io_init(CYBSP_DEBUG_UART_TX, CYBSP_DEBUG_UART_RX, UART_DEFAULT_STREAM_BAUD_RATE);
#endif
    printf("System initialized!\r\n");
    
    /* Initialize the elapsed timer */
    elapsed_timer_init();

    printf("\x1b[2J\x1b[;H");

    printf("****************** "
           "Neural Network Profiler "
           "****************** \r\n\n");
    
    printf("This configuration set to use %s data source.\r\n",
           (REGRESSION_DATA_SOURCE == USE_STREAM_DATA) ? "stream" : "local");
    printf("Profiling configuration set to %s.\r\n",
           (PROFILE_CONFIGURATION == MTB_ML_PROFILE_DISABLE) ? "disabled profiling" :
           (PROFILE_CONFIGURATION == MTB_ML_PROFILE_ENABLE_MODEL) ? "enable profiling model" :
           (PROFILE_CONFIGURATION == MTB_ML_PROFILE_ENABLE_LAYER) ? "enable profiling layer" :
           (PROFILE_CONFIGURATION == MTB_ML_PROFILE_ENABLE_MODEL_PER_FRAME) ? "enable profiling model per frame" :
           (PROFILE_CONFIGURATION == MTB_ML_PROFILE_ENABLE_LAYER_PER_FRAME) ? "enable profiling layer per frame" :
           (PROFILE_CONFIGURATION == MTB_ML_LOG_ENABLE_MODEL_LOG) ? "enable profiling model log" : "unknown");
    printf("Model size: %d bytes\r\n", MTB_ML_MODEL_SIZE(MODEL_NAME));
    printf("Send 'help' to see available commands.\r\n");
    fflush(stdout); 

    mtb_ml_model_bin_t model_bin = {MTB_ML_MODEL_BIN_DATA(MODEL_NAME)};

#if REGRESSION_DATA_SOURCE == USE_STREAM_DATA
    mtb_ml_stream_interface_t interface = {CY_ML_INTERFACE_UART, &cy_retarget_io_uart_obj};

    result = mtb_ml_stream_init(&interface, PROFILE_CONFIGURATION, &model_bin);
#else
    result = ml_local_regression_init(PROFILE_CONFIGURATION, &model_bin);
#endif    

    if(result != CY_RSLT_SUCCESS)
    {
        printf("ERROR: initialization of the ML profiler failed!\r\n");
        CY_HALT();
    }
    else
    {
        // Initialize model object for protocol commands
        #if REGRESSION_DATA_SOURCE == USE_LOCAL_DATA
        result = mtb_ml_model_init(&model_bin, NULL, &model_object);
        if(result != MTB_ML_RESULT_SUCCESS)
        {
            printf("ERROR: Model initialization failed!\r\n");
            CY_HALT();
        }
        #endif
    }

    for (;;)
    {
        uint8_t ch;
        if (cyhal_uart_getc(&cy_retarget_io_uart_obj, &ch, 0) == CY_RSLT_SUCCESS){
            if (ch == '\r' || ch == '\n')
            {
                if (buffer_index > 0)
                {
                    uart_buffer[buffer_index] = '\0';
                    
                    printf("\r\nCommand: %s\r\n", uart_buffer);
                    
                    if (strcmp(uart_buffer, "start") == 0){
                        #if REGRESSION_DATA_SOURCE == USE_STREAM_DATA
                            result = mtb_ml_stream_task();
                        #else
                            result = ml_local_regression_task();
                        #endif

                        #if REGRESSION_DATA_SOURCE == USE_LOCAL_DATA
                            cy_retarget_io_init(CYBSP_DEBUG_UART_TX, CYBSP_DEBUG_UART_RX, CY_RETARGET_IO_BAUDRATE);
                        #else
                            cy_retarget_io_init(CYBSP_DEBUG_UART_TX, CYBSP_DEBUG_UART_RX, UART_DEFAULT_STREAM_BAUD_RATE);
                        #endif

                        if (result == CY_RSLT_SUCCESS)
                        {
                            printf("\n\rProfiling completed!\n\r");
                        }
                        else
                        {
                            printf("\n\rProfiling task failed!\n\r");
                        }
                    } else if (strcmp(uart_buffer, "help") == 0) {
                        printf("=== Neural Network Profiler Help ===\r\n");
                        printf("This profiler supports two operational modes:\r\n");
                        printf("1. STREAM_MODE - receives data via UART from host\r\n");
                        printf("2. LOCAL_MODE - uses pre-loaded regression data\r\n");
                        
                        printf("Available User Commands:\r\n");
                        printf("  start  - begin ML profiling task\r\n");
                        printf("  status - show system status\r\n");
                        printf("  help   - show this help message\r\n");
                        printf("  clean  - clear screen\r\n");
                        printf("  exit   - exit application\r\n\r\n");
                        
                        printf("ML Stream Protocol Commands:\r\n");
                        printf("  %s - initiate profiling session\r\n", ML_TC_START_STRING);
                        printf("  %s - request model information\r\n", ML_TC_MODEL_DATA_REQ_STRING);
                        printf("  %s - request dataset transmission\r\n", ML_TC_DATASET_REQ_SEND_STRING);
                        printf("  %s - request frame processing\r\n", ML_CT_FRAME_REQ_STRING);
                        printf("  %s - signal completion\r\n", ML_TC_DONE_STRING);
                        printf("\r\nML Responses (sent by device):\r\n");
                        printf("  %s - device ready\r\n", ML_CT_READY_STRING);
                        printf("  %s - model data follows\r\n", ML_CT_MODEL_DATA_STRING);
                        printf("  %s - result data follows\r\n", ML_CT_RESULT_STRING);
                        printf("  %s - session done\r\n", ML_CT_DONE_STRING);

                    } else if (strcmp(uart_buffer, "clean") == 0){
                        printf("\x1b[2J\x1b[;H");
                    } else if (strcmp(uart_buffer, "exit") == 0) {
                        printf("Exiting...\r\n");
                        break;
                    } else if (strcmp(uart_buffer, ML_TC_START_STRING) == 0) {
                        printf("%s\r\n", ML_CT_READY_STRING);
                        printf("Device ready to receive ML commands\r\n");
                    } else if (strcmp(uart_buffer, ML_TC_MODEL_DATA_REQ_STRING) == 0) {
                        printf("%s\r\n", ML_CT_MODEL_DATA_STRING);
                        if(model_object != NULL) {
                            printf("Model: %s\r\n", model_object->name);
                            printf("Model size: %d bytes\r\n", model_object->model_size);
                            printf("Input size: %d\r\n", model_object->input_size);
                            printf("Output size: %d\r\n", model_object->output_size);
                            printf("Buffer size: %d bytes\r\n", model_object->buffer_size);
                        } else {
                            printf("Model: TEST_MODEL\r\n");
                            printf("Model size: %d bytes\r\n", MTB_ML_MODEL_SIZE(MODEL_NAME));
                        }
                    } else if (strcmp(uart_buffer, ML_TC_DATASET_REQ_SEND_STRING) == 0) {
                        printf("%s\r\n", ML_CT_READY_STRING);
                        printf("Ready to receive dataset\r\n");
                        printf("Send %s to transmit frame data\r\n", ML_CT_FRAME_REQ_STRING);
                    } else if (strcmp(uart_buffer, ML_CT_FRAME_REQ_STRING) == 0) {
                        printf("%s\r\n", ML_CT_RESULT_STRING);
                        printf("Simulating frame processing...\r\n");
                        if(model_object != NULL) {
                            printf("Ready to process %d input elements\r\n", model_object->input_size);
                        }
                    } else if (strcmp(uart_buffer, ML_TC_DONE_STRING) == 0) {
                        printf("%s\r\n", ML_CT_DONE_STRING);
                        printf("ML session completed\r\n");
                    } else if (strcmp(uart_buffer, "status") == 0) {
                        printf("=== System Status ===\r\n");
                        printf("Mode: %s\r\n", (REGRESSION_DATA_SOURCE == USE_STREAM_DATA) ? "STREAM" : "LOCAL");
                        if(model_object != NULL) {
                            printf("Model: %s\r\n", model_object->name);
                            printf("Model size: %d bytes\r\n", model_object->model_size);
                            printf("Input size: %d elements\r\n", model_object->input_size);
                            printf("Output size: %d elements\r\n", model_object->output_size);
                        }
                        printf("Profile config: %s\r\n",
                               (PROFILE_CONFIGURATION == MTB_ML_PROFILE_ENABLE_MODEL) ? "MODEL" : "OTHER");
                    } else if (buffer_index == 0) {
                        // 
                    } else {
                        printf("Unknown command: %s\r\n", uart_buffer);
                        printf("Type 'help' to see available commands\r\n");
                    }
                }

                printf("\r\n> "); 
                fflush(stdout);
                buffer_index = 0;
            }
            else if (buffer_index < sizeof(uart_buffer) - 1)
            {
                uart_buffer[buffer_index++] = (char)ch;
                printf("%c", ch);
                fflush(stdout);
            }
        }
    }
}

/* [] END OF FILE */
