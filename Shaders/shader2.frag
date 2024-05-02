#version 460 core

in vec3 Normal;
in vec3 FragPos;
in vec2 textCoords;

out vec4 FragColor;

struct Material{
    
    sampler2D diffuse;
    sampler2D specular;
    float shininess;
};

struct Light{
 vec3 position;
 vec3 direction;
 
 vec3 ambient;
 vec3 diffuse;
 vec3 specular;

 float cutOff;

 float constant;
 float linear;
 float quadratic;
};
uniform vec3 objectColor;
uniform vec3 lightColor;
uniform vec3 viewPos;

uniform Material material;
uniform Light light;
void main()
{
   
   
    vec3 lightDir = normalize(light.position - FragPos);
    float theta = dot(lightDir, normalize(-light.direction));

    if (theta > light.cutOff)
    {
    vec3 ambient = texture(material.diffuse,textCoords).rgb * light.ambient;
    
    vec3 norm = normalize(Normal);
    float diff = max(dot(norm, lightDir),0.0);
    vec3 diffuse =  light.diffuse * diff * texture(material.diffuse,textCoords).rgb;
    
    vec3 viewDir = normalize(viewPos - FragPos);
    vec3 reflectDir = reflect(-lightDir,norm);
    float spec = pow(max(dot(viewDir,reflectDir),0.0),material.shininess);

    vec3 specular =  light.specular * spec * texture(material.specular,textCoords).rgb;

    float distance =  length(light.position - FragPos);
    float attenuation = 1.0 / ( light.constant + light.linear * distance + light.quadratic * (distance * distance));
    
    diffuse *= attenuation;
    specular *= attenuation;
    
    vec3 result = (ambient + diffuse + specular) ;
   FragColor = vec4(result, theta);
    }
    else
    {
    FragColor =vec4(light.ambient * texture(material.diffuse, textCoords).rgb, 1.0);
   }
}