# Модуль Е: решение

Нам предстоит поменять код пакета turtlebro_delivery, а так же добавить его запуск в автозагрузку. Сначала делаем все изменения и проверяем, и только когда все полностью готово и работает, добавляем в автозагрузку и проверяем
Если вы понимаете, что не сможете изменить код для добавления подсветки, сделайте только автозагрузку. это принесет вам часть баллов. Если вы сделаете все с подсветкой, но автозагрузка не заработает, то эксперты ничего не смогут проверить (потому что вам запрещено пользоваться ноутбуком при сдаче модуля, то есть вы никак не сможете запустить доставку вручную из терминала)

## Добавление подсветки

1. **Добавляем светоодиодную ленту в Arduino**
Для начала модифицируем код для ардуино. Нам нужно добавить в него включение разных цветов на светодиодной ленте в зависимости от того, какие сообщения нам придут от ROS на роботе. Пока не важно, как эти сообщения будут приходить. ПРосто договоримся, что ROS будет отправлять числа, и в зависимости от того, что это за число, будем включать разные цвета:
- 0 = выключить ленту (для отладки можно использовать синий цвет)
- 1 = зеленый (ожидание товара)
- 2 = Желтый (перемещение по полигону)
- 3 = красный (ожидание вручения товара)

У нас уже есть код delivery.ino, который мы загружали в первом модуле для проверки работы кнопки, крышки багажника и концевика. Мы взяли его из репозитория turtlebro_delivery: https://github.com/voltbro/turtlebro_extra/tree/master/turtlebro_delivery/arduino/delivery 
сам код вот :
```cpp
#include <Servo.h>
#include <ros.h>
#include "std_msgs/Int16.h"

#define END_SWITCH A12 
#define TOP_BUTTON A15  
#define CAP_SERVO 46  


int cap_servo_open = 0;
int cap_servo_close = 85;

//arduino to ROS connect init
class NewHardware : public ArduinoHardware
{
  public:
  NewHardware():ArduinoHardware(&Serial1, 115200){};
};
 
//ROS node init
ros::NodeHandle_<NewHardware>  nh;
 
//Servos and pins init
Servo cap_servo;

std_msgs::Int16 top_button;
ros::Publisher button_pub("top_button", &top_button);

std_msgs::Int16 end_switch;
ros::Publisher end_switch_pub("end_switch", &end_switch);


void CbCapServo( const std_msgs::Int16& msg){
    if (msg.data == 1){
        cap_servo.write(cap_servo_open);
    } 
    if (msg.data == 0){
      cap_servo.write(cap_servo_close);
    }
}

ros::Subscriber<std_msgs::Int16> subCapServo("top_cap", &CbCapServo );

void setup() {

  Serial.begin(115200);

  cap_servo.attach(CAP_SERVO);
  cap_servo.write(cap_servo_open);  

  pinMode(END_SWITCH, INPUT);
  pinMode(TOP_BUTTON, INPUT_PULLUP);
  //ROS nodes init
  nh.initNode();

  nh.subscribe(subCapServo);

  nh.advertise(button_pub);
  nh.advertise(end_switch_pub);

}

void loop() {
  // put your main code here, to run repeatedly:
  nh.spinOnce();

  top_button.data = !digitalRead(TOP_BUTTON);
  button_pub.publish( &top_button );

  end_switch.data = digitalRead(END_SWITCH);
  end_switch_pub.publish( &end_switch );
  delay(50);

}
```

Управлять светодиодной лентой будем через библиотеку FastLED. Она у вас уже загружена - мы использовали ее так же в модуле A при проверке кнопок и собственно ленты.
В самое начало arduino кода добавляем подключение 2 библиотек:
```cpp
#include <FastLED.h> //библиотека для светодидной ленты
#include "std_msgs/Int16.h" //библиотека с типом сообщения, которое придет из ROS
```
Зачем вторая? Это модуль из библиотеки `ros`, который хранит описание сообщения, которое придет из ROS-а в нашу ардуину. Дело в том, что, вроде как мы будем отправлять просто число (0,1,2,3), но из ROS-а придет не число, а **сообщение с числом**. Чтобы ардуина смогла прочитать это сообщение и взять из него число, нам и нужен этот модуль.

Далее добавим строки, в которых определим два значения - количество светодиодов и к какому пину подключена лента:
```cpp
#define LED_PIN 6  // К какому пину подключена лента
#define NUM_LEDS 10  // Количество светодиодов
```
Далее, ниже под всеми строками #define мы "создаем" нашу светодиодную ленту. Делаем это командой:
```cpp
CRGB leds[NUM_LEDS]; //создаем ленту с кол-вом светодиодов = NUM_LEDS
```
Далее нам нужно написать две функции. Они должны находиться **в любом месте между #define-ами и функцией void setup()**.
**Первая функция - изменить цвет ленты.** По сути лента - это массив rgb цветов светодиодов. То есть нам нужно записать в каждый светодиод его цвет, а цвет будет передаваться в эту функцию как три числа (r, g и b от 0 до 255):
```cpp
void setLedColor(int r, int g, int b) {    //создаем функцию с 3мя агрументами 
  for (int i = 0; i < NUM_LEDS; i++) {     // выполнить столько раз, сколько светодиодов в ленте
    leds[i] = CRGB(r, g, b);               // записать цвет i-того светодиода
  }
  FastLED.show();                          // отобразить цвет на ленте
}
```
**Вторая функция** (пишем ее ниже первой) нужна для перевода числа из ROS (1, 2,3 или 0) в цвет светодиодов:
```cpp
// Функция, которая принимает данные из ROS и меняет цвет ленты
void ledCallback(const std_msgs::Int16 &msg) { //создаем функцию с 1 вргументом - сообщение с числом из ROS
  switch (msg.data) {                          // в зависимости от числа изменить цвет на:
    case 1: setLedColor(0, 255, 0); break;     // Зеленый
    case 2: setLedColor(255, 255, 0); break;   // Желтый
    case 3: setLedColor(255, 0, 0); break;     // Красный
    default: setLedColor(0, 0, 0); break;      // Выключить (по умолчанию)
  }
}
```
Ниже этой функции нам нужно создать ros-подписчика. Чтобы получать сообщения из какого-то топика в ros, нужно на него подписаться. **Ниже под написанными только что функциями (и до функции void setup())** пишем:
```cpp
ros::Subscriber<std_msgs::Int16> subLed("led_strip", &ledCallback);
```
эта функция делает рос-подписчика на топик `led_strip` (потом мы его создадим в роботе) и вызывает функцию `ledCallback` со значением, пришедшим из этого топика.
Наконец, **внутри функции void setup()** инициализируем ленту и по умолчанию она выключена (в любом месте setup-а добавляем эти строчки):
```cpp
FastLED.addLeds<WS2812, LED_PIN, GRB>(leds, NUM_LEDS); //инициализация ленты
setLedColor(0, 0, 0); // Выключаем ленту при запускеи в этой же функции setup добавляем подписку на топик (активируем рос подписчика, которого создали ранее):
nh.subscribe(subLed);
```
(`subLed` - так мы ранее назвали нашего подписчика)
Код для ардуино готов. Сохраните его под новым названием (чтобы не потерять старый) и загрузите в ардуино на роботе через кабель microUSB.
Вот полный код, который должен получиться:
```cpp
#include <FastLED.h>
#include <Servo.h>
#include <ros.h>
#include "std_msgs/Int16.h"

#define END_SWITCH A12 
#define TOP_BUTTON A15  
#define CAP_SERVO 46  

/* ========= ADDED START ========= */
#define LED_PIN 30
#define NUM_LEDS 24

CRGB leds[NUM_LEDS];
/* ========= ADDED END ========= */

int cap_servo_open = 0;
int cap_servo_close = 85;

//arduino to ROS connect init
class NewHardware : public ArduinoHardware
{
  public:
  NewHardware():ArduinoHardware(&Serial1, 115200){};
};
 
//ROS node init
ros::NodeHandle_<NewHardware>  nh;
 
//Servos and pins init
Servo cap_servo;

std_msgs::Int16 top_button;
ros::Publisher button_pub("top_button", &top_button);

std_msgs::Int16 end_switch;
ros::Publisher end_switch_pub("end_switch", &end_switch);


void CbCapServo( const std_msgs::Int16& msg){
    if (msg.data == 1){
        cap_servo.write(cap_servo_open);
    } 
    if (msg.data == 0){
      cap_servo.write(cap_servo_close);
    }
}

ros::Subscriber<std_msgs::Int16> subCapServo("top_cap", &CbCapServo );
/* ========= ADDED START ========= */
void setLedColor(int r, int g, int b) {
  for (int i = 0; i < NUM_LEDS; i++) {
    leds[i] = CRGB(r, g, b);
  }
  FastLED.show();
}

void ledCallback(const std_msgs::Int16 &msg) {
  switch (msg.data) {
    case 1: setLedColor(0, 255, 0); break;  // Зеленый
    case 2: setLedColor(255, 255, 0); break; // Желтый
    case 3: setLedColor(255, 0, 0); break;  // Красный
    default: setLedColor(0, 0, 255); break;   // Выключить
  }
}

ros::Subscriber<std_msgs::Int16> subLed("led_strip", &ledCallback);
/* ========= ADDED END ========= */

void setup() {

  Serial.begin(115200);

  /* ========= ADDED START ========= */
  FastLED.addLeds<WS2812, LED_PIN, GRB>(leds, NUM_LEDS);
  setLedColor(0, 0, 0); // Выключаем ленту при запуске
  /* ========= ADDED END ========= */

  cap_servo.attach(CAP_SERVO);
  cap_servo.write(cap_servo_open);  

  pinMode(END_SWITCH, INPUT);
  pinMode(TOP_BUTTON, INPUT_PULLUP);
  //ROS nodes init
  nh.initNode();

  nh.subscribe(subCapServo);
  
  /* ========= ADDED START ========= */
  nh.subscribe(subLed);
  /* ========= ADDED END ========= */
 
  nh.advertise(button_pub);
  nh.advertise(end_switch_pub);

}

void loop() {
  // put your main code here, to run repeatedly:
  nh.spinOnce();

  top_button.data = !digitalRead(TOP_BUTTON);
  button_pub.publish( &top_button );

  end_switch.data = digitalRead(END_SWITCH);
  end_switch_pub.publish( &end_switch );
  delay(50);

}
```
2. Добавляем управление лентой в пакет turtlebro_delivery

Предполагаем, что вы не знакомы ни с программированием Ардуино, ни с питоном.
Для начала стоит прочитать базу про объекты и классы:
- <a href="https://proproprogs.ru/python_oop/koncepciya-oop-prostymi-slovami" target="_blank">Концепция ООП простыми словами</a>
- <a href="https://proproprogs.ru/python_oop/klassy-i-obekty-atributy-klassov-i-obektov" target="_blank">Классы, объекты, атрибуты</a>

Изменять будем файлы пакета turtlebro_delivery, которые лежать в репозитории пакета в папке src https://github.com/voltbro/turtlebro_extra/tree/master/turtlebro_delivery/src

Что там есть:
- `delivery_deivices.py` - здесь описаны все ардуино устройства, подключенные к ROS робота
- `delivery.py` - основной код, реализует логику доставки
- `delivery_speech.py` - берет основной код delivery.py и добавляет в него озвучку
- `speech_client.py` - реализация озвучки (этот код нас не интересует)

Прежде чем менять код в файлах далее, скопируйте старые файлы (прямо в той же папке их можно оставить)

1) **Изменение delivery_devices.py**

Итак, у нас сейчас есть код вот такой:

*delivery_devices.py (old)*
```python
from std_msgs.msg import Int16
import rospy

class TopCap():
    state = 'unknow'
    end_switch = 0

    def __init__(self) -> None:

        self.end_switch_sub = rospy.Subscriber("/end_switch", Int16, self.end_switch_cb)
        self.top_cap_pub    = rospy.Publisher("/top_cap", Int16, queue_size=5)
        
        rospy.sleep(1)
        rospy.loginfo("TopCap init done")

        self.open()


    def open(self):
        if self.state != 'open':
            rospy.loginfo('Open top cap')
            self.state = 'open'
            self.top_cap_pub.publish(1)

    def close(self):
        if self.state == 'open':
            rospy.loginfo('Close top cap')
            self.state = 'closed'
            self.top_cap_pub.publish(0)

    def is_closed(self):
        return bool(self.end_switch)    

    def end_switch_cb(self, msg:Int16):
        self.end_switch = msg.data

class Button():

    button = 0

    def __init__(self) -> None:
        self.sub = rospy.Subscriber("/top_button", Int16, self.button_cb)
        rospy.loginfo("TopButton init done")

    def is_pressed(self):            
        return bool(self.button)

    def button_cb(self, msg:Int16):
        self.button = msg.data   
```
      
В нем описаны устройства, которые сейчас есть (`class TopCap()` - крышка багажника (то есть ее сервопривод), `class Button()` - кнопка зеленая). Добавим класс светодиодной ленты. В самом низу файла добавьте вот такой код:
```python
class LedStrip():
    def __init__(self) -> None:
        self.led_pub = rospy.Publisher("/led_strip", Int16, queue_size=5)
        rospy.loginfo("LED Strip initialized")
    
    def set_color(self, color_code: int):
        """ Устанаваливает цвет ленты (0 - выкл, 1 - зеленый, 2 - желтый, 3 - красный)"""
        self.led_pub.publish(color_code)
```
Это класс `LedStrip`, у него два метода (функции):
- `init` - это просто инициализация. Строка 
    ```python
    self.led_pub = rospy.Publisher("/led_strip", Int16, queue_size=5)
    ```
    создает издателя (publisher) под названием `led_pub`, который будет публиковать в топик `/led_strip` сообщения типа `Int16` (сообщение с целым числом); вторая строка просто выводит в лог сообщение `"LED Strip initialized"`
- `set_color()` - функция, которая будет отправлять номер цвета в топик с помощью издателя led_pub

Файл delivery_devices.py готов

*delivery_devices.py (new)*
```python
from std_msgs.msg import Int16
import rospy

class TopCap():
    state = 'unknow'
    end_switch = 0

    def __init__(self) -> None:

        self.end_switch_sub = rospy.Subscriber("/end_switch", Int16, self.end_switch_cb)
        self.top_cap_pub    = rospy.Publisher("/top_cap", Int16, queue_size=5)
        
        rospy.sleep(1)
        rospy.loginfo("TopCap init done")

        self.open()


    def open(self):
        if self.state != 'open':
            rospy.loginfo('Open top cap')
            self.state = 'open'
            self.top_cap_pub.publish(1)

    def close(self):
        if self.state == 'open':
            rospy.loginfo('Close top cap')
            self.state = 'closed'
            self.top_cap_pub.publish(0)

    def is_closed(self):
        return bool(self.end_switch)    

    def end_switch_cb(self, msg:Int16):
        self.end_switch = msg.data

class Button():

    button = 0

    def __init__(self) -> None:
        self.sub = rospy.Subscriber("/top_button", Int16, self.button_cb)
        rospy.loginfo("TopButton init done")

    def is_pressed(self):            
        return bool(self.button)

    def button_cb(self, msg:Int16):
        self.button = msg.data   

class LedStrip():
    def __init__(self) -> None:
        self.led_pub = rospy.Publisher("/led_strip", Int16, queue_size=5)
        rospy.loginfo("LED Strip initialized")
    
    def set_color(self, color_code: int):
        """ Устанаваливает цвет ленты (0 - выкл, 1 - зеленый, 2 - желтый, 3 - красный)"""
        self.led_pub.publish(color_code)
```

2) **Изменение delivery.py**

Теперь основной код. Логика такая: нам нужно вставить в нужные места функцию `set_color` из класса светодиодной ленты с соответствующим числом в скобках (1, 2, 3, 0).
Вот исходный код delivery.py:

*delivery.py (old)*
```python
#!/usr/bin/env python3

import rospy
import math
import toml

import actionlib
from pathlib import Path

from actionlib_msgs.msg import GoalStatus
from move_base_msgs.msg import MoveBaseAction, MoveBaseGoal
from turtlebro_aruco.srv import ArucoDetect, ArucoDetectResponse, ArucoDetectRequest

from delivery_devices import Button, TopCap
from tf.transformations import quaternion_from_euler


class DeliveryRobot():

    def __init__(self) -> None:

        rospy.on_shutdown(self.on_shutdown)

        self.rate = rospy.Rate(5)
        self.client: dict = {}
        self.state: str = 'product_wait'

        self.top_cap = TopCap()
        self.start_button = Button()

        self.aruco_service = rospy.ServiceProxy('aruco_detect', ArucoDetect)
        rospy.loginfo(f"Waiting for aruco service")
        self.aruco_service.wait_for_service()
        rospy.loginfo(f"Have aruco service")

        self.move_base_client = actionlib.SimpleActionClient(
            'move_base', MoveBaseAction)
        rospy.loginfo("Waiting move_base action")
        self.move_base_client.wait_for_server()
        rospy.loginfo(f"Have move_base action")

        self.load_delivery_config()

        self.set_state('robot_start')
        rospy.loginfo("Init done")

    def spin(self):

        while not rospy.is_shutdown():

            # точка загрузки, ждем код в камеру
            if self.state in ['robot_start', 'product_wait', 'have_product_error', 'delivery_error']:
                self.top_cap.open()

                aruco_result: ArucoDetectResponse = self.aruco_service.call(
                    ArucoDetectRequest())

                if aruco_result.id > 0:
                    self.client = self._find_client_by_product(aruco_result.id)

                    if self.client:
                        rospy.loginfo(
                            f"Have {self.client['name']} product: {aruco_result.id}")
                        self.set_state('have_product')
                    else:
                        rospy.loginfo(
                            f"No client for product {aruco_result.id}")
                        self.set_state('have_product_error')

            # точка загрузки, ждем нажатие кнопки
            if self.state == 'have_product':
                if self.start_button.is_pressed():
                    self.set_state('home_cap_close_wait')
                    self.top_cap.close()

            # точка загрузки, ждем закрытие крышки и едем
            if self.state == 'home_cap_close_wait':
                if self.top_cap.is_closed():
                    rospy.loginfo(f"On {self.client['name']} way")
                    self.set_state('move_to_delivery_point')

                    goal = self._goal_message_assemble(self.client['pose'])
                    self.move_base_client.send_goal(goal, done_cb=self.move_client_cb)

            # точка клиента, ждем аруко код
            if self.state in ['on_delivery_point', 'client_pickup_error']:
                aruco_result: ArucoDetectResponse = self.aruco_service.call(
                    ArucoDetectRequest())
                if aruco_result.id > 0:
                    # check client secret
                    if aruco_result.id == self.client['secret']:
                        rospy.loginfo(f"Client secret confirmed")
                        self.top_cap.open()
                        self.client = {}
                        self.set_state('client_pickup_wait')
                    else:
                        rospy.loginfo(f"Wrong client secret")
                        self.set_state('client_pickup_error')

            # точка клиента, ждем когда заберут и нажмут кнопку
            if self.state == 'client_pickup_wait':
                if self.start_button.is_pressed():
                    self.set_state('client_cap_close_wait')
                    self.top_cap.close()

            # точка клиента, ждем когда крышка будет закрыта и едем домой
            if self.state == 'client_cap_close_wait':
                self.top_cap.close()
                rospy.loginfo(f"On home way")
                self.set_state('move_to_home_point')

                goal = self._goal_message_assemble(
                    self.delivery_config['home']['pose'])
                self.move_base_client.send_goal(
                    goal, done_cb=self.move_home_cb)

            self.rate.sleep()

    def move_client_cb(self, status, result):

        if status == GoalStatus.PREEMPTED:
            rospy.loginfo("Delivery point cancelled")
            self.set_state('delivery_error')

        if status == GoalStatus.SUCCEEDED:
            rospy.loginfo("Delivery point reached")
            self.set_state('on_delivery_point')

    def move_home_cb(self, status, result):

        if status == GoalStatus.PREEMPTED:
            rospy.loginfo("Move to home point cancelled")
            self.set_state('delivery_error')

        if status == GoalStatus.SUCCEEDED:
            rospy.loginfo("Move to home point reached")
            self.set_state('product_wait')

    def set_state(self, state: str):
        self.state = state

    def load_delivery_config(self):

        config_file = rospy.get_param('~delivery_config_file', str(
            Path(__file__).parent.absolute()) + '/../data/delivery.toml')

        rospy.loginfo(f"Loading config file {config_file}")

        self.delivery_config = toml.load(config_file)

    def _find_client_by_product(self, product) -> dict():
        for key, value in self.delivery_config.items():
            if key != 'home':
                if product in value['products']:
                    value['name'] = key
                    return value

        return dict()

    def _goal_message_assemble(self, pose):
        # Creates a new goal with the MoveBaseGoal constructor
        goal = MoveBaseGoal()
        # Move to x, y meters of the "map" coordinate frame
        goal.target_pose.header.frame_id = "map"
        goal.target_pose.header.stamp = rospy.Time.now()
        goal.target_pose.pose.position.x = float(pose['x'])
        goal.target_pose.pose.position.y = float(pose['y'])

        q = quaternion_from_euler(0, 0, math.radians(float(pose['theta'])))

        goal.target_pose.pose.orientation.x = q[0]
        goal.target_pose.pose.orientation.y = q[1]
        goal.target_pose.pose.orientation.z = q[2]
        goal.target_pose.pose.orientation.w = q[3]

        rospy.loginfo("Created goal from point {} ".format(pose))

        return goal

    def on_shutdown(self):

        rospy.loginfo("Shutdown Delivery bot")
        self.move_base_client.action_client.stop()
        rospy.sleep(0.5)


if __name__ == '__main__':
    try:
        rospy.init_node('delivery_node')

        robot = DeliveryRobot()

        robot.spin()

    except rospy.ROSInterruptException:

        robot.on_shutdown()
        rospy.loginfo("Delivery stopped due to ROS interrupt")
```
Прежде всего нам нужно в самом начале кода импортировать класс `LedStrip` из delivery_devices. Найдите в начале строку:
```python
from delivery_devices import Button, TopCap
```
и добавьте в конце:
```python
from delivery_devices import Button, TopCap, LedStrip
```
И еще из delivery_devices нужно скопировать и вставить там же в начале delivery.py  строчку:
```python
from std_msgs.msg import Int16
```
Затем нам нужно в коде робота добавить ленту (как объект)
Найдите вот этот кусок кода и рядом с `self.top_cap = TopCap()` и `self.start_button = Button()` добавьте `self.led_strip = LedStrip()`

```python
class DeliveryRobot():

    def __init__(self) -> None:

        rospy.on_shutdown(self.on_shutdown)

        self.rate = rospy.Rate(5)
        self.client: dict = {}
        self.state: str = 'product_wait'

        self.top_cap = TopCap()
        self.start_button = Button()
        """вот сюда"""Получится вот так:
class DeliveryRobot():

    def __init__(self) -> None:

        rospy.on_shutdown(self.on_shutdown)

        self.rate = rospy.Rate(5)
        self.client: dict = {}
        self.state: str = 'product_wait'

        self.top_cap = TopCap()
        self.start_button = Button()
        self.led_strip = LedStrip()
```
Далее в коде нам нужно вставить вот такие команды (каждую в свое место, это просто список):
```python
self.led_strip.set_color(1)  # Зеленый - ожидание товара
self.led_strip.set_color(2)  # Желтый - перемещение
self.led_strip.set_color(3)  # Красный - ожидание вручения
self.led_strip.set_color(0)  # Выключение ленты- огда робот ждет загрузки товара, загорается зеленый (set_color(1)).
```
- Когда едет к клиенту или обратно, загорается желтый (set_color(2)).
- Когда ждет, пока клиент заберет товар, включается красный (set_color(3)).
- В остальных ситуациях лента выключается (set_color(0)).

Основной код находится в функции `spin(self)` (после строчки `def spin(self):`)
Ориентироваться в нем нам помогут комментарии, которые уже есть в исходном коде.
В самом начале функции spin есть строчка `#точка загрузки, ждем код в камеру`
```python
            # точка загрузки, ждем код в камеру
            if self.state in ['robot_start', 'product_wait', 'have_product_error', 'delivery_error']:
                self.top_cap.open() 
                
                """вот сюда вставляем команду для зеленого цвета"""
                self.led_strip.set_color(1) # зеленый = ожидание товара

                aruco_result: ArucoDetectResponse = self.aruco_service.call(
                    ArucoDetectRequest())
```
Следующее - ищем `#точка загрузки, ждем закрытие крышки и едем`
Сюда вставим желтый цвет:
```python
            # точка загрузки, ждем закрытие крышки и едем
            if self.state == 'home_cap_close_wait':
                if self.top_cap.is_closed():
                    rospy.loginfo(f"On {self.client['name']} way")
                    
                    """вот сюда вставляем команду для желтого цвета"""
                    self.led_strip.set_color(2) # желтый = перемещение
                    
                    self.set_state('move_to_delivery_point')

                    goal = self._goal_message_assemble(self.client['pose'])
                    self.move_base_client.send_goal(goal, done_cb=self.move_client_cb)
```
Также желтый цвет вставляем на обратной дороге: (`# точка клиента, ждем когда крышка будет закрыта и едем домой`)
```python
            # точка клиента, ждем когда крышка будет закрыта и едем домой
            if self.state == 'client_cap_close_wait':
                self.top_cap.close()
                rospy.loginfo(f"On home way")
                
                """вот сюда вставляем команду для желтого цвета"""
                self.led_strip.set_color(2) # желтый = перемещение
                
                self.set_state('move_to_home_point')

                goal = self._goal_message_assemble(
                    self.delivery_config['home']['pose'])
                self.move_base_client.send_goal(
                    goal, done_cb=self.move_home_cb)
```
Теперь красный, ищем строчку `# точка клиента, ждем аруко код`
```python
            # точка клиента, ждем аруко код
            if self.state in ['on_delivery_point', 'client_pickup_error']:
                
                """вот сюда вставляем команду для красного цвета"""
                self.led_strip.set_color(3) # красный = ожидание вручения
                
                aruco_result: ArucoDetectResponse = self.aruco_service.call(
                    ArucoDetectRequest())
                if aruco_result.id > 0:
                    # check client secret
                    if aruco_result.id == self.client['secret']:
                        rospy.loginfo(f"Client secret confirmed")
                        self.top_cap.open()
                        self.client = {}
                        self.set_state('client_pickup_wait')
                    else:
                        rospy.loginfo(f"Wrong client secret")
                        self.set_state('client_pickup_error')
```
Наконец, нам нужно выключить ленту там, где она должна быть выключена. Для этого ищем функцию `def set_state(self, state: str):`
```python
def set_state(self, state: str):
        self.state = state
        
        """дописываем во такой код - если состояние не из тех, что мы смотрели ранее, то выключить ленту"""
        if state not in ['product_wait', 'move_to_delivery_point', 'on_delivery_point', 'client_cap_close_wait']:
            self.led_strip.set_color(0) #выключить ленту во всех остальных состояниях
            
И так же выключаем ленту, если доставка выключена (найдите ближе к концу строчку: `def on_shutdown(self):`)
```python
 def on_shutdown(self):

        rospy.loginfo("Shutdown Delivery bot")
        self.move_base_client.action_client.stop()
        self.led_strip.set_color(0) # выключаем ленту при завершении
        rospy.sleep(0.5)
```
Код delivery.py готов

*delivery.py (new)*
```python
#!/usr/bin/env python3

import rospy
import math
import toml

import actionlib
from pathlib import Path

from actionlib_msgs.msg import GoalStatus
from move_base_msgs.msg import MoveBaseAction, MoveBaseGoal
from turtlebro_aruco.srv import ArucoDetect, ArucoDetectResponse, ArucoDetectRequest

from delivery_devices import Button, TopCap, LedStrip
from tf.transformations import quaternion_from_euler
from std_msgs.msg import Int16


class DeliveryRobot():

    def __init__(self) -> None:

        rospy.on_shutdown(self.on_shutdown)

        self.rate = rospy.Rate(5)
        self.client: dict = {}
        self.state: str = 'product_wait'

        self.top_cap = TopCap()
        self.start_button = Button()
        self.led_strip = LedStrip()

        self.aruco_service = rospy.ServiceProxy('aruco_detect', ArucoDetect)
        rospy.loginfo(f"Waiting for aruco service")
        self.aruco_service.wait_for_service()
        rospy.loginfo(f"Have aruco service")

        self.move_base_client = actionlib.SimpleActionClient(
            'move_base', MoveBaseAction)
        rospy.loginfo("Waiting move_base action")
        self.move_base_client.wait_for_server()
        rospy.loginfo(f"Have move_base action")

        self.load_delivery_config()

        self.set_state('robot_start')
        rospy.loginfo("Init done")

    def spin(self):

        while not rospy.is_shutdown():

            # точка загрузки, ждем код в камеру
            if self.state in ['robot_start', 'product_wait', 'have_product_error', 'delivery_error']:
                self.top_cap.open()
                self.led_strip.set_color(1) # зеленый = ожидание товара

                aruco_result: ArucoDetectResponse = self.aruco_service.call(
                    ArucoDetectRequest())

                if aruco_result.id > 0:
                    self.client = self._find_client_by_product(aruco_result.id)

                    if self.client:
                        rospy.loginfo(
                            f"Have {self.client['name']} product: {aruco_result.id}")
                        self.set_state('have_product')
                    else:
                        rospy.loginfo(
                            f"No client for product {aruco_result.id}")
                        self.set_state('have_product_error')
                    

            # точка загрузки, ждем нажатие кнопки
            if self.state == 'have_product':
                if self.start_button.is_pressed():
                    self.set_state('home_cap_close_wait')
                    self.top_cap.close()
                

            # точка загрузки, ждем закрытие крышки и едем
            if self.state == 'home_cap_close_wait':
                if self.top_cap.is_closed():
                    rospy.loginfo(f"On {self.client['name']} way")
                    self.led_strip.set_color(2) # желтый = перемещение
                    self.set_state('move_to_delivery_point')

                    goal = self._goal_message_assemble(self.client['pose'])
                    self.move_base_client.send_goal(goal, done_cb=self.move_client_cb)
                    

            # точка клиента, ждем аруко код
            if self.state in ['on_delivery_point', 'client_pickup_error']:
                
                aruco_result: ArucoDetectResponse = self.aruco_service.call(
                    ArucoDetectRequest())
                if aruco_result.id > 0:
                    # check client secret
                    if aruco_result.id == self.client['secret']:
                        rospy.loginfo(f"Client secret confirmed")
                        self.top_cap.open()
                        self.client = {}
                        self.set_state('client_pickup_wait')
                    else:
                        rospy.loginfo(f"Wrong client secret")
                        self.set_state('client_pickup_error')
                self.led_strip.set_color(3) # красный = ожидание вручения
                    

            # точка клиента, ждем когда заберут и нажмут кнопку
            if self.state == 'client_pickup_wait':
                if self.start_button.is_pressed():
                    self.set_state('client_cap_close_wait')
                    self.top_cap.close()
                    

            # точка клиента, ждем когда крышка будет закрыта и едем домой
            if self.state == 'client_cap_close_wait':
                self.top_cap.close()
                rospy.loginfo(f"On home way")
                self.led_strip.set_color(2) # желтый = перемещение
                self.set_state('move_to_home_point')

                goal = self._goal_message_assemble(
                    self.delivery_config['home']['pose'])
                self.move_base_client.send_goal(
                    goal, done_cb=self.move_home_cb)
                

            self.rate.sleep()

    def move_client_cb(self, status, result):

        if status == GoalStatus.PREEMPTED:
            rospy.loginfo("Delivery point cancelled")
            self.set_state('delivery_error')

        if status == GoalStatus.SUCCEEDED:
            rospy.loginfo("Delivery point reached")
            self.set_state('on_delivery_point')

    def move_home_cb(self, status, result):

        if status == GoalStatus.PREEMPTED:
            rospy.loginfo("Move to home point cancelled")
            self.set_state('delivery_error')

        if status == GoalStatus.SUCCEEDED:
            rospy.loginfo("Move to home point reached")
            self.set_state('product_wait')

    def set_state(self, state: str):
        self.state = state
        if state not in ['product_wait', 'move_to_delivery_point', 'on_delivery_point']:
            self.led_strip.set_color(0) #выключить ленту во всех остальный состояниях

    def load_delivery_config(self):

        config_file = rospy.get_param('~delivery_config_file', str(
            Path(__file__).parent.absolute()) + '/../data/delivery.toml')

        rospy.loginfo(f"Loading config file {config_file}")

        self.delivery_config = toml.load(config_file)

    def _find_client_by_product(self, product) -> dict():
        for key, value in self.delivery_config.items():
            if key != 'home':
                if product in value['products']:
                    value['name'] = key
                    return value

        return dict()

    def _goal_message_assemble(self, pose):
        # Creates a new goal with the MoveBaseGoal constructor
        goal = MoveBaseGoal()
        # Move to x, y meters of the "map" coordinate frame
        goal.target_pose.header.frame_id = "map"
        goal.target_pose.header.stamp = rospy.Time.now()
        goal.target_pose.pose.position.x = float(pose['x'])
        goal.target_pose.pose.position.y = float(pose['y'])

        q = quaternion_from_euler(0, 0, math.radians(float(pose['theta'])))

        goal.target_pose.pose.orientation.x = q[0]
        goal.target_pose.pose.orientation.y = q[1]
        goal.target_pose.pose.orientation.z = q[2]
        goal.target_pose.pose.orientation.w = q[3]

        rospy.loginfo("Created goal from point {} ".format(pose))

        return goal

    def on_shutdown(self):

        rospy.loginfo("Shutdown Delivery bot")
        self.move_base_client.action_client.stop()
        self.led_strip.set_color(0) # выключаем ленту при завершении
        rospy.sleep(0.5)


if __name__ == '__main__':
    try:
        rospy.init_node('delivery_node')

        robot = DeliveryRobot()

        robot.spin()

    except rospy.ROSInterruptException:

        robot.on_shutdown()
        rospy.loginfo("Delivery stopped due to ROS interrupt")
```

3. **Изменение delivery_speech.py**
ничего не нужно менять. потому что delivery_speech подтягивает delivery.py, а мы все изменения там уже написали

Готово!

4. **Автозагрузка**
Теперь, предположим, вы как **минимум 5 раз проверили свой модифицированный пакет доставки**, и готовы добавить его в автозагрузку. Немного информации об этом есть в инструкции к роботу: https://manual.turtlebro.ru/paket-turtlebro/params#fail-turtlebro.launch (раздел Пакет turtlebro, параметры и настройка через launch, файл turtlebro.launch)
Нам как раз нужен файл turtlebro.launch, причем тот, который лежит в роботе по адресу `/etc/ros/turtlebro.d/turtlebro.launch`
В этот файл нам нужно добавить 1 строчку:
```xml
<include file="$(find turtlebro_delivery)/launch/delivery_speech.launch"/>
```
Эта строчка добавляет файл delivery_speech.launch из пакета turtlebro_delivery в автозагрузку!
Файл целиком:
```xml
<launch>

    <arg name="run_rosserial" default="true"/>
    <arg name="run_rplidar" default="true"/>
    <arg name="run_turtlebro_web" default="true"/>
    <arg name="run_camera_ros" default="true"/>

    <arg name="run_simple_odom" default="true"/>



    <include file="$(find turtlebro)/launch/rosserial.launch" if="$(arg run_rosserial)"/>
    <include file="$(find turtlebro)/launch/robot_model.launch"/>

    <include file="$(find turtlebro)/launch/camera_ros.launch" if="$(arg run_camera_ros)"/>

    <include file="$(find turtlebro)/launch/rplidar.launch" if="$(arg run_rplidar)"/>

    <include file="$(find turtlebro_web)/launch/turtlebro_web.launch" if="$(arg run_turtlebro_web)"/>

    <include file="$(find turtlebro)/launch/simple_odom.launch" if="$(arg run_simple_odom)"/>
    
    ВОТ НАША СТРОЧКА:
    <include file="$(find turtlebro_delivery)/launch/delivery_speech.launch"/>


</launch>
```