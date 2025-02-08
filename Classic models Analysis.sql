/*================================================================
					Partie I : ANALYSE PRODUITS
==================================================================*/

/* KPI 1 : la valeur du stock pour chaque productline 
la valorisation ici se fait au prix d'achat
*/

SELECT 
	productLine,
    productName,
    SUM(quantityInStock * buyPrice) AS valeur_stock
FROM classicmodels.products
GROUP BY productLine, productName ;

/* KPI 2 : Quels sont les produits les moins démandés ? */

CREATE TABLE classicmodels.chiffre_affaire AS
    SELECT 
		table1.orderNumber,
		table1.customerNumber,
		table1.orderDate,
		table2.productCode,
		table2.quantityOrdered,
		table2.priceEach
	FROM   classicmodels.orders AS table1
		RIGHT JOIN classicmodels.orderdetails AS table2
		ON table1.orderNumber = table2.orderNumber ;

SELECT
	table2.productCode,
	table2.productName,
    table2.quantityInStock,
	IFNULL(SUM(table1.quantityOrdered),0) AS demande_total_produit,
	table2.buyPrice
FROM classicmodels.chiffre_affaire AS table1
			RIGHT JOIN classicmodels.products AS table2
			ON table1.productCode = table2.productCode
GROUP BY table2.productCode, table2.productName, table2.buyPrice
ORDER BY demande_total_produit ASC ;


/* KPI 3: Quels est le taux d'écoulement du stock ?

Cet indicateur mesure la proportion de stock écoulé(commandée) qui sur la période 
*/

CREATE TABLE classicmodels.ecoulement_stock AS
SELECT
	productName,
    ROUND((demande_total_produit / (quantityInStock + demande_total_produit)) * 100, 2) AS taux_ecoulement_stock
FROM(
		SELECT
			table2.productCode,
			table2.productName,
			table2.quantityInStock,
			SUM(IFNULL(table1.quantityOrdered, 0)) AS demande_total_produit,
			table2.buyPrice
		FROM classicmodels.chiffre_affaire AS table1
					RIGHT JOIN classicmodels.products AS table2
					ON table1.productCode = table2.productCode
		GROUP BY table2.productCode, table2.productName, table2.buyPrice ) AS ryusaki ;
        
        
/* KPI 4 : Quels est le taux de rotation du stock ?

taux de rotation du stock = Coût des marchandises vendues / valeur du stocks moyens

Coût des marchandises vendues : (prix d'achat * quantité)
Stocks moyens : prix d'achat * (Stock initial + stock final)/2

Cet indicateur mesure le nombre de fois que les stocks 
sont vendus et renouvelés pendant une période donnée(dans notre notre cas 3 année). 
Un taux de rotation élevé signifie que les produits se vendent rapidement, 
tandis qu'un taux faible suggère de faible ventes par rapport aux stocks.
*/

CREATE TABLE classicmodels.rotation_stock AS
SELECT  
    b.productCode,  
    b.productName,  
    ROUND((a.cout_achat /b.valeur_stock_moyen),2) AS rotation  
FROM (  
			SELECT  
				tableA.productCode,  
				SUM(tableA.quantityOrdered * tableB.buyPrice) AS cout_achat 
			FROM classicmodels.orderdetails AS tableA  
				JOIN classicmodels.products AS tableB 
				USING (productCode)  
			GROUP BY tableA.productCode  ) AS a  
RIGHT JOIN (  
			SELECT  
				ryusaki.productCode, 
				ryusaki.productName,  
				ryusaki.buyPrice*((ryusaki.quantityInStock + 2 *(ryusaki.demande_total_produit)) / 2) AS valeur_stock_moyen  
			FROM (  
				SELECT  
					table1.productCode,  
					table1.productName,  
					table1.quantityInStock,
                    table1.buyPrice,
					SUM(IFNULL(table2.quantityOrdered, 0)) AS demande_total_produit  
				FROM classicmodels.products AS table1  
					RIGHT JOIN classicmodels.chiffre_affaire AS table2 
					USING (productCode)  
				GROUP BY table1.productCode, table1.productName, table1.quantityInStock ) AS ryusaki  ) AS b 
USING (productCode) ;

        
/* KPI 5 : Quelle est la rentabilité par produit ?
 
marge_par_produit : C'est la différence entre
la valeur d'acquision ou coût d'achat (quantité * prix d'achat)
et le revenu brut ou les recettes ( quantités vendues * prix de vente)
*/
CREATE TABLE classicmodels.marge_produit AS
SELECT
	productLine,
	productName,
	(valeur_vente -valeur_acquisition) AS revenu_brut
FROM(
SELECT
	table2.productLine,
	table2.productCode,
	table2.productName,
	SUM(table1.quantityOrdered) AS demande_total_produit,
	SUM(table2.buyPrice* table1.quantityOrdered) As valeur_acquisition,
	SUM(table1.priceEach* table1.quantityOrdered) AS valeur_vente
FROM classicmodels.chiffre_affaire AS table1
	RIGHT JOIN classicmodels.products AS table2
	ON table1.productCode = table2.productCode
WHERE table1.quantityOrdered != 0
GROUP BY table2.productCode, table2.productName ) AS ryusaki  ;

/* KPI 6 : Quelle est la rentabilité par ligne de produit ?
*/
SELECT
	productLine,
    SUM(revenu_brut) marge_ligne_produit
FROM classicmodels.marge_produit
GROUP BY productLine ;


/*================================================================
					Partie III : ANALYSE COMMANDES
==================================================================*/

/* KPI 7 : Quel est le délais moyen de traitement des commandes livrées ? */
SELECT
	CONCAT(ROUND(AVG(delais_traitement),0), " Jours") AS delais_moyen_traitement
FROM(
	SELECT
		orderNumber,
		SUM(requiredDate - shippedDate ) AS delais_traitement
	FROM classicmodels.orders 
    WHERE orderNumber != '10165' AND status = "Shipped"  
	GROUP BY orderNumber ) AS ryusaki ;
    
/* KPI 8 : Quelle est la répartition des commandes par type de produit */
    
SELECT
    productLine,
    commande_ligne_produit,
    CONCAT(ROUND((commande_ligne_produit / total_chiffre_affaire) * 100, 2),"%") AS part_chiffre_affaire
FROM (
    SELECT
        table1.productLine,
        SUM(table2.priceEach * table2.quantityOrdered) AS commande_ligne_produit,
        (SELECT SUM(priceEach * quantityOrdered) FROM classicmodels.chiffre_affaire) AS total_chiffre_affaire
    FROM classicmodels.products AS table1
        RIGHT JOIN classicmodels.chiffre_affaire AS table2
        ON table1.productCode = table2.productCode
    GROUP BY table1.productLine) AS ryusaki
ORDER BY commande_ligne_produit DESC ;
    
/* KPI 9 : Quelle sont les demandes(Commandes) mensuelles  ? */ 

SELECT
    MONTHNAME(orderDate) AS mois,
    SUM(quantityOrdered) AS demande
FROM classicmodels.chiffre_affaire
WHERE MONTH(orderDate) BETWEEN 1 AND 12
GROUP BY mois
ORDER BY mois ;

/* KPI 10 : Quelle sont les demandes(Commandes) anuelles ? */ 

SELECT
    YEAR(orderDate) AS annee,
    SUM(quantityOrdered) AS demande
FROM classicmodels.chiffre_affaire
WHERE YEAR(orderDate) IN (2003, 2004, 2005)
GROUP BY annee
ORDER BY annee ;

/* KPI 11 : Quel est le taux de commandes annulées ? */ 

SELECT 
    commande_totale,
    commande_annulee,
    CONCAT(ROUND((commande_annulee / commande_totale)*100, 2), " %") AS taux_annulation
FROM 
    (SELECT COUNT(*) AS commande_annulee FROM classicmodels.orders WHERE status = 'Cancelled') AS annulee,
    (SELECT COUNT(*) AS commande_totale FROM classicmodels.orders) AS total ;
    
/*================================================================
					Partie II : ANALYSE CLIENTS
==================================================================*/

/* KPI 12 : Qui sont les clients inactifs ? 

ce sont tout les clienst qui n'ont commandés aucun produit sur toute la période
*/

SELECT
	table2.customerNumber,
    table2.country,
    table2.customerName
FROM classicmodels.commande_client 	AS table1
	RIGHT JOIN classicmodels.customers 	AS table2
    ON table1.customerNumber = table2.customerNumber
WHERE table1.chiffre_affaire_client IS NULL ;

/* KPI 13 : Quels clients génèrent le plus de chiffre d'affaires et où sont-ils localisés ? 

Chiffre_affaire_client : Ce montant représente valeur totale de commande par client
-- Utilisation d'une wiews
*/

CREATE TABLE classicmodels.commande_client AS
SELECT
	table2.customerNumber,
	table1.customerName,
    table1.country,
    SUM(table2.priceEach * table2.quantityOrdered) AS chiffre_affaire_client
FROM classicmodels.customers AS table1
	RIGHT JOIN classicmodels.chiffre_affaire AS table2
    ON table1.customerNumber = table2.customerNumber
GROUP BY table2.customerNumber, table1.customerName, table1.country 
ORDER BY chiffre_affaire_client DESC ;

/* KPI 14 : Quels sont les  clients dont le chiffre d'affaire
 dépassent le seuil de 500.000 USD et où sont-ils localisés ? */

SELECT 
	customerName,
    country,
    chiffre_affaire_client
FROM classicmodels.commande_client
WHERE chiffre_affaire_client >= 500000 ;

/* KPI 15 : Quelle est la durée moyenne de paiement par client ? */

SELECT
	table1.customerName,
    ROUND(AVG(DATEDIFF(table2.paymentDate, table3.orderDate)),0) as duree_moyenne_paiement
FROM classicmodels.customers AS table1
	JOIN classicmodels.payments AS table2
		ON table1.customerNumber = table2.customerNumber
    JOIN classicmodels.orders AS table3
		ON table1.customerNumber = table3.customerNumber
WHERE table2.paymentDate >= table3.orderDate
GROUP BY table1.customerName ;


/* KPI 16 : Taux de recouvrement
Ce indicateur mésure La part des paiements reçus 
par rapport au montant total de la commande de chaque client */


CREATE TABLE classicmodels.recouvrement AS
SELECT
	tableB.customerNumber,
	tableB.customerName,
    tableB.chiffre_affaire_client AS montant_total_commande,
    SUM(tableA.amount) AS montant_total_paye,
    ROUND((SUM(tableA.amount) / tableB.chiffre_affaire_client)*100,2) AS Taux_recouvrement 
FROM classicmodels.payments AS tableA
RIGHT JOIN classicmodels.commande_client AS tableB
ON tableB.customerNumber = tableA.customerNumber
GROUP BY 	tableB.customerNumber, tableB.customerName, tableB.chiffre_affaire_client ;


/*================================================================
					Partie IV : ANALYSE EMPLOYES
==================================================================*/

/* KPI 17 : Quels employé obtiennent les meilleurs résultats ? 

Chaque client est associé à un employé de l'entreprise.
Un employé est considéré comme le plus performant si la valeur totale 
des commandes passées par ses clients est la plus élevée.
*/

/* Etape 1 : on créer d'abord une table qui associe chaque employé aux valeurs
des commandes passées par ses clients */


CREATE TABLE classicmodels.employee_ca AS
SELECT 
    tableA.salesRepEmployeeNumber,
    tableA.customerNumber,
    tableB.customerName,
    tableA.country,
    tableB.chiffre_affaire_client
FROM classicmodels.customers AS tableA
	RIGHT JOIN (
			SELECT
			table2.customerNumber,
			table1.customerName,
			table1.country,
			SUM(table2.priceEach * table2.quantityOrdered) AS chiffre_affaire_client
			FROM classicmodels.customers AS table1
				RIGHT JOIN classicmodels.chiffre_affaire AS table2
				ON table1.customerNumber = table2.customerNumber
			GROUP BY table2.customerNumber, table1.customerName, table1.country) AS tableB
	ON tableA.customerNumber = tableB.customerNumber ; 
    
    /* Etape 2 : output final */
   
SELECT
	table1.salesRepEmployeeNumber AS identifiant_employee,
	CONCAT(table2.firstName," ",table2.lastName)  AS nom_employee,
    table2.jobTitle,
    table1.country,
    SUM(table1.chiffre_affaire_client) AS chiffre_affaire_employee
FROM classicmodels.employee_ca AS table1
	RIGHT JOIN classicmodels.employees AS table2
    ON table1.salesRepEmployeeNumber =  table2.employeeNumber
WHERE table1.salesRepEmployeeNumber IS NOT NULL
GROUP BY identifiant_employee, table1.country, nom_employee 
ORDER BY chiffre_affaire_employee DESC ;

/* KPI 18 : Quelle est la performance des employés par pays ? */

SELECT		
	country,
    SUM(chiffre_affaire_employee) AS chiffre_affaire_employee
FROM (
	SELECT
	table1.salesRepEmployeeNumber AS identifiant_employee,
	CONCAT(table2.firstName," ",table2.lastName)  AS nom_employee,
    table2.jobTitle,
    table1.country,
    SUM(table1.chiffre_affaire_client) AS chiffre_affaire_employee
	FROM classicmodels.employee_ca AS table1
		RIGHT JOIN classicmodels.employees AS table2
		ON table1.salesRepEmployeeNumber =  table2.employeeNumber
	WHERE table1.salesRepEmployeeNumber IS NOT NULL
	GROUP BY identifiant_employee, table1.country, nom_employee 
	ORDER BY chiffre_affaire_employee DESC ) AS ryusaki
GROUP BY country ;

/* KPI 19 : Quels employés ont une charge de travail élevée (nombre de clients gérés) ? */

SELECT
    table2.employeeNumber,
    CONCAT(table2.lastName," ",table2.firstName) as nom_complet,
    COUNT(DISTINCT(table1.customerNumber)) as nombre_clients
FROM classicmodels.employee_ca as table1
	RIGHT JOIN classicmodels.employees as table2
    ON table1.salesRepEmployeeNumber = table2.employeeNumber
WHERE salesRepEmployeeNumber IS NOT NULL
GROUP BY table1.salesRepEmployeeNumber, nom_complet 
ORDER BY nombre_clients DESC ;


/* Des tables qui aiderons à l'implémentation des graphiques dans Power BI */

CREATE TABLE customer_orders_summary AS 
SELECT 	
	table1.orderNumber,
	table1.quantityOrdered,
    table2.orderDate,
    table2.customerNumber
FROM classicmodels.orderdetails AS table1
LEFT JOIN classicmodels.orders AS table2 
ON table1.orderNumber = table2.orderNumber ;


CREATE TABLE classicmodels.value_stock_quantity AS
SELECT 
	productLine,
    productName,
    sum(quantityInStock) * buyPrice as valeur_stock
FROM classicmodels.products
GROUP BY productLine, productName, buyPrice
ORDER BY valeur_stock DESC ;
